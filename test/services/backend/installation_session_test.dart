import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/backend/backend_transport.dart';
import 'package:vinyl_app/services/backend/installation_session.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'backend_test_support.dart';

void main() {
  late MemoryBackendStore store;
  setUp(() {
    store = MemoryBackendStore();
  });
  InstallationSession make(BackendSender sender) {
    final transport = BackendTransport(sender: sender);
    addTearDown(transport.close);
    return InstallationSession(
      origin: Uri.parse('https://api.groovefolio.app'),
      store: store,
      transport: transport,
      now: () => fixedNow,
      newToken: () => nextToken,
    );
  }

  test(
    'no registration on reads; simultaneous explicit connects register once',
    () async {
      var calls = 0;
      final session = make((method, uri, headers, body, limit) async {
        calls++;
        expect(method, 'POST');
        expect(uri.path, '/v1/installations');
        expect(body, '{}');
        expect(headers.containsKey('Authorization'), isFalse);
        return response(201, {...identity(), 'token': oldToken});
      });
      expect(await session.hasSession(), isFalse);
      expect(calls, 0);
      await Future.wait([
        session.registerIfNeeded(),
        session.registerIfNeeded(),
      ]);
      expect(calls, 1);
      expect(await session.hasSession(), isTrue);
      expect(store.legacyClears, 2);
    },
  );

  test(
    'serializes renewal and persists successor before transmission',
    () async {
      store.seed(days: 1);
      var rotations = 0;
      final session = make((method, uri, headers, body, limit) async {
        if (uri.path.endsWith('/rotate')) {
          rotations++;
          expect(
            jsonDecode(store.values['session']!)['pendingToken'],
            nextToken,
          );
          expect(headers['Authorization'], 'Bearer $oldToken');
          expect(jsonDecode(body!)['nextToken'], nextToken);
          return response(200, identity());
        }
        expect(headers['Authorization'], 'Bearer $nextToken');
        return response(200, {'connected': true});
      });
      await Future.wait([
        session.request('GET', '/v1/discogs/account'),
        session.request('GET', '/v1/discogs/account'),
      ]);
      expect(rotations, 1);
      expect(jsonDecode(store.values['session']!)['pendingToken'], isNull);
    },
  );

  test(
    'lost rotation response survives restart and probes persisted successor first',
    () async {
      store.seed(days: 1);
      final initial = make((method, uri, headers, body, limit) async {
        throw TimeoutException('lost');
      });
      await expectLater(
        initial.request('GET', '/v1/discogs/account'),
        throwsA(isA<DiscogsNetworkFailure>()),
      );
      expect(jsonDecode(store.values['session']!)['pendingToken'], nextToken);
      final seen = <String>[];
      final recovered = make((method, uri, headers, body, limit) async {
        seen.add(uri.path);
        expect(headers['Authorization'], 'Bearer $nextToken');
        return response(
          200,
          uri.path == '/v1/installation' ? identity() : {'connected': true},
        );
      });
      await recovered.request('GET', '/v1/discogs/account');
      expect(seen, ['/v1/installation', '/v1/discogs/account']);
    },
  );

  test(
    'unsent successor recovers via old token and reuses same successor',
    () async {
      store.seed(days: 1, pending: nextToken);
      final seen = <String>[];
      final session = make((method, uri, headers, body, limit) async {
        seen.add('$method ${uri.path}');
        if (uri.path == '/v1/installation' &&
            headers['Authorization'] == 'Bearer $nextToken') {
          return response(401, {'code': 'authentication_required'});
        }
        if (uri.path.endsWith('/rotate')) {
          expect(jsonDecode(body!)['nextToken'], nextToken);
        }
        return response(200, identity());
      });
      await session.request('GET', '/v1/discogs/account');
      expect(seen, [
        'GET /v1/installation',
        'GET /v1/installation',
        'POST /v1/installation/rotate',
        'GET /v1/discogs/account',
      ]);
    },
  );

  test(
    'ambiguous recovery failure retains both tokens and never registers',
    () async {
      store.seed(pending: nextToken);
      final before = store.values['session'];
      final session = make(
        (method, uri, headers, body, limit) async => response(503),
      );
      await expectLater(
        session.request('GET', '/v1/discogs/account'),
        throwsA(isA<DiscogsNetworkFailure>()),
      );
      expect(store.values['session'], before);
    },
  );

  test('storage failure prevents sending rotation', () async {
    store.seed(days: 1);
    store.failWrites = true;
    var calls = 0;
    final session = make((method, uri, headers, body, limit) async {
      calls++;
      return response(200, identity());
    });
    await expectLater(
      session.request('GET', '/v1/discogs/account'),
      throwsStateError,
    );
    expect(calls, 0);
    expect(jsonDecode(store.values['session']!)['token'], oldToken);
  });

  test(
    'definite invalid token clears session and flow without replaying mutation',
    () async {
      store.seed();
      store.seedFlow();
      var calls = 0;
      final session = make((method, uri, headers, body, limit) async {
        calls++;
        return response(401, {'code': 'authentication_required'});
      });
      await expectLater(
        session.request('POST', '/v1/discogs/connections'),
        throwsA(isA<DiscogsAuthenticationFailure>()),
      );
      expect(calls, 1);
      expect(store.values, isEmpty);
    },
  );

  test(
    'failed promotion write recovers a successfully rotated token',
    () async {
      store.seed(days: 1);
      final first = make((method, uri, headers, body, limit) async {
        expect(uri.path, '/v1/installation/rotate');
        store.failWrites = true;
        return response(200, identity());
      });
      await expectLater(
        first.request('GET', '/v1/discogs/account'),
        throwsStateError,
      );
      expect(jsonDecode(store.values['session']!)['pendingToken'], nextToken);
      store.failWrites = false;
      final recovered = make((method, uri, headers, body, limit) async {
        expect(method, 'GET');
        expect(headers['Authorization'], 'Bearer $nextToken');
        return response(200, identity());
      });
      await recovered.request('GET', '/v1/discogs/account');
      expect(jsonDecode(store.values['session']!)['token'], nextToken);
      expect(jsonDecode(store.values['session']!)['pendingToken'], isNull);
    },
  );

  test('edge rejection and rate limit retain identity', () async {
    for (final status in [401, 403, 429, 503]) {
      store.seed();
      final before = store.values['session'];
      var calls = 0;
      final session = make((method, uri, headers, body, limit) async {
        calls++;
        return response(status, null, {'retry-after': '60'});
      });
      await expectLater(
        session.request('GET', '/v1/discogs/account'),
        throwsA(isA<DiscogsFailure>()),
      );
      expect(store.values['session'], before);
      expect(calls, 1);
    }
  });
}
