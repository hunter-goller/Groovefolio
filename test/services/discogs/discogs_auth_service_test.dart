import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/backend/backend_transport.dart';
import 'package:vinyl_app/services/backend/installation_session.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_auth_service.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import '../backend/backend_test_support.dart';

void main() {
  late MemoryBackendStore store;
  setUp(() {
    store = MemoryBackendStore()..seed();
  });
  DiscogsAuthService make(
    BackendSender sender, {
    DiscogsBrowserLauncher? launcher,
  }) {
    final transport = BackendTransport(sender: sender);
    addTearDown(transport.close);
    final session = InstallationSession(
      origin: Uri.parse('https://api.groovefolio.app'),
      store: store,
      transport: transport,
      now: () => fixedNow,
    );
    return DiscogsAuthService(
      apiClient: DiscogsApiClient(session, transport),
      store: store,
      launcher: launcher,
    );
  }

  test(
    'flow persisted before browser launch and recovered after process restart',
    () async {
      var status = 'pending';
      Future<BackendResponse> sender(
        String method,
        Uri uri,
        Map<String, String> headers,
        String? body,
        int limit,
      ) async {
        if (method == 'POST') {
          expect(body, isNull);
          return response(201, {
            'transactionId': flowId,
            'expiresAt': fixedNow
                .add(const Duration(minutes: 10))
                .toIso8601String(),
            'authorizationUrl':
                'https://www.discogs.com/oauth/authorize?oauth_token=temporary',
          });
        }
        if (uri.path.endsWith('/account')) {
          return response(200, {
            'connected': true,
            'discogsId': 7,
            'username': 'listener',
          });
        }
        return response(200, {'transactionId': flowId, 'status': status});
      }

      final auth = make(
        sender,
        launcher: (uri) async {
          expect(store.values['flow'], isNotNull);
          return true;
        },
      );
      await auth.launchAuthorization();
      expect(store.values['flow'], isNot(contains('oauth_token')));
      expect(await make(sender).authorizationStatus(), 'pending');
      status = 'connected';
      expect(await make(sender).authorizationStatus(), 'connected');
      expect(store.values.containsKey('flow'), isFalse);
    },
  );
  test('network failure retains flow; terminal failure clears it', () async {
    store.seedFlow();
    final offline = make((method, uri, headers, body, limit) async {
      throw TimeoutException('offline');
    });
    await expectLater(
      offline.authorizationStatus(),
      throwsA(isA<DiscogsNetworkFailure>()),
    );
    expect(store.values['flow'], isNotNull);
    final expired = make(
      (method, uri, headers, body, limit) async =>
          response(200, {'status': 'expired'}),
    );
    await expectLater(
      expired.authorizationStatus(),
      throwsA(isA<DiscogsAuthenticationFailure>()),
    );
    expect(store.values['flow'], isNull);
    expect(store.values['session'], isNotNull);
  });
  test(
    'cancel and disconnect call server before clearing saved state',
    () async {
      store.seedFlow();
      final paths = <String>[];
      final auth = make((method, uri, headers, body, limit) async {
        expect(method, 'DELETE');
        expect(store.values['flow'], isNotNull);
        paths.add(uri.path);
        return response(204);
      });
      await auth.cancelAuthorization();
      expect(store.values['flow'], isNull);
      store.seedFlow();
      await auth.disconnect();
      expect(paths, ['/v1/discogs/connections/$flowId', '/v1/discogs/account']);
      expect(store.values['flow'], isNull);
      expect(store.values['session'], isNotNull);
    },
  );
  test('failed disconnect preserves saved state for retry', () async {
    store.seedFlow();
    final auth = make(
      (method, uri, headers, body, limit) async => response(503),
    );
    await expectLater(auth.disconnect(), throwsA(isA<DiscogsNetworkFailure>()));
    expect(store.values['flow'], isNotNull);
    expect(store.values['session'], isNotNull);
  });
  test('rejects an untrusted browser authorization URL', () async {
    final auth = make(
      (method, uri, headers, body, limit) async => response(201, {
        'transactionId': flowId,
        'authorizationUrl': 'https://evil.example/oauth/authorize',
      }),
    );
    await expectLater(
      auth.beginAuthorization(),
      throwsA(isA<DiscogsApiFailure>()),
    );
    expect(store.values['flow'], isNull);
  });
}
