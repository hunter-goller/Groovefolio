import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/backend/backend_transport.dart';
import 'package:vinyl_app/services/backend/installation_session.dart';
import 'package:vinyl_app/services/discogs/discogs_keep_alive.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';

import '../backend/backend_test_support.dart';

void main() {
  late MemoryBackendStore store;
  late DateTime now;
  late List<String> requests;

  setUp(() {
    store = MemoryBackendStore();
    now = fixedNow;
    requests = [];
  });

  DiscogsKeepAlive make(BackendSender sender) {
    final transport = BackendTransport(
      sender: (method, uri, headers, body, limit) {
        requests.add('$method ${uri.path}');
        return sender(method, uri, headers, body, limit);
      },
    );
    addTearDown(transport.close);
    return DiscogsKeepAlive(
      InstallationSession(
        origin: Uri.parse('https://api.groovefolio.app'),
        store: store,
        transport: transport,
        now: () => now,
        newToken: () => nextToken,
      ),
      now: () => now,
    );
  }

  Future<BackendResponse> ok(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
    int limit,
  ) async => response(200, identity());

  test('does nothing when Discogs was never connected', () async {
    final keepAlive = make(ok);
    expect(await keepAlive.checkIn(), DiscogsCheckIn.skipped);
    expect(requests, isEmpty);
  });

  test('checks in once a day with the saved connection', () async {
    store.seed();
    final keepAlive = make((method, uri, headers, body, limit) async {
      expect(headers['Authorization'], 'Bearer $oldToken');
      expect(body, isNull);
      return response(200, identity());
    });

    expect(await keepAlive.checkIn(), DiscogsCheckIn.ok);
    expect(requests, ['GET /v1/installation']);

    now = now.add(const Duration(hours: 5));
    expect(await keepAlive.checkIn(), DiscogsCheckIn.skipped);
    expect(requests, hasLength(1));

    now = now.add(const Duration(hours: 16));
    expect(await keepAlive.checkIn(), DiscogsCheckIn.ok);
    expect(requests, hasLength(2));
  });

  test('renews a token that is about to expire', () async {
    store.seed(days: 2);
    final keepAlive = make(ok);

    expect(await keepAlive.checkIn(), DiscogsCheckIn.ok);

    expect(requests, ['POST /v1/installation/rotate', 'GET /v1/installation']);
    expect(jsonDecode(store.values['session']!)['token'], nextToken);
  });

  test('reports a connection the server has already ended', () async {
    store.seed();
    store.seedFlow();
    final keepAlive = make(
      (method, uri, headers, body, limit) async =>
          response(401, {'code': 'authentication_required'}),
    );

    expect(await keepAlive.checkIn(), DiscogsCheckIn.lost);
    expect(store.values, isEmpty, reason: 'the dead connection is cleared');
  });

  test('offline check-ins are retried next time', () async {
    store.seed();
    var offline = true;
    final keepAlive = make((method, uri, headers, body, limit) async {
      if (offline) throw TimeoutException('offline');
      return response(200, identity());
    });

    expect(await keepAlive.checkIn(), DiscogsCheckIn.failed);
    expect(store.values['session'], isNotNull, reason: 'nothing is cleared');
    offline = false;
    expect(await keepAlive.checkIn(), DiscogsCheckIn.ok);
    expect(requests, hasLength(2));
  });

  test('overlapping check-ins share one request', () async {
    store.seed();
    final gate = Completer<void>();
    final keepAlive = make((method, uri, headers, body, limit) async {
      await gate.future;
      return response(200, identity());
    });

    final first = keepAlive.checkIn();
    final second = keepAlive.checkIn();
    gate.complete();
    expect(await Future.wait([first, second]), [
      DiscogsCheckIn.ok,
      DiscogsCheckIn.ok,
    ]);
    expect(requests, hasLength(1));
  });

  testWidgets('the app scope checks in and reports a lost connection', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        discogsKeepAliveProvider.overrideWithValue(
          _FixedKeepAlive(DiscogsCheckIn.lost),
        ),
        discogsAccountProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DiscogsKeepAliveScope(child: Text('app')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('app'), findsOneWidget);
    expect(container.read(discogsConnectionLostProvider), isTrue);
  });

  testWidgets('a healthy check-in reports nothing', (tester) async {
    final container = ProviderContainer(
      overrides: [
        discogsKeepAliveProvider.overrideWithValue(
          _FixedKeepAlive(DiscogsCheckIn.ok),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DiscogsKeepAliveScope(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(discogsConnectionLostProvider), isFalse);
  });
}

class _FixedKeepAlive implements DiscogsKeepAlive {
  _FixedKeepAlive(this.result);
  final DiscogsCheckIn result;

  @override
  Future<DiscogsCheckIn> checkIn() async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
