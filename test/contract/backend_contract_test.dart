import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/backend/backend_transport.dart';
import 'package:vinyl_app/services/backend/installation_session.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_auth_service.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

import '../services/backend/backend_test_support.dart';

/// Runs the app's real parsing over the backend's responses, byte for byte.
/// See test/contract/backend/README.md.
void main() {
  String raw(String name) =>
      File('test/contract/backend/$name').readAsStringSync();
  Object? fixture(String name) => jsonDecode(raw(name));
  BackendResponse reply(int status, String name) => BackendResponse(
    status,
    Uint8List.fromList(utf8.encode(raw(name))),
    const {'content-type': 'application/json'},
  );

  late MemoryBackendStore store;
  setUp(() => store = MemoryBackendStore());

  ({InstallationSession session, DiscogsApiClient api, DiscogsAuthService auth})
  make(BackendSender sender) {
    final transport = BackendTransport(sender: sender);
    addTearDown(transport.close);
    final session = InstallationSession(
      origin: Uri.parse('https://api.groovefolio.app'),
      store: store,
      transport: transport,
      now: () => fixedNow,
      newToken: () => nextToken,
    );
    final api = DiscogsApiClient(session, transport);
    return (
      session: session,
      api: api,
      auth: DiscogsAuthService(
        apiClient: api,
        store: store,
        launcher: (_) async => true,
      ),
    );
  }

  group('installation', () {
    test('registration is stored with the exact expiry', () async {
      final client = make((method, uri, headers, body, limit) async {
        expect('$method ${uri.path}', 'POST /v1/installations');
        expect(body, '{}');
        return reply(201, 'installation_registered.json');
      });
      await client.session.registerIfNeeded();

      final saved = jsonDecode(store.values['session']!) as Map;
      final sent = fixture('installation_registered.json')! as Map;
      expect(saved['installationId'], sent['installationId']);
      expect(saved['token'], sent['token']);
      expect(
        DateTime.parse(saved['expiresAt'] as String),
        DateTime.utc(2026, 10, 27, 0, 0, 0, 123, 456),
      );
    });

    test('rotation sends the expected body and reads the status', () async {
      store.seed(days: 1);
      final client = make((method, uri, headers, body, limit) async {
        if (uri.path == '/v1/installation/rotate') {
          final expected = fixture('installation_rotate_request.json')! as Map;
          final sent = jsonDecode(body!) as Map;
          expect(sent.keys, expected.keys);
          expect(sent['nextToken'], isA<String>());
          expect((sent['nextToken'] as String).length, 43);
          return reply(200, 'installation_status.json');
        }
        return reply(200, 'discogs_account_connected.json');
      });
      await client.session.request('GET', '/v1/discogs/account');

      final saved = jsonDecode(store.values['session']!) as Map;
      expect(saved['token'], nextToken);
      expect(saved['pendingToken'], isNull);
      expect(
        DateTime.parse(saved['expiresAt'] as String),
        DateTime.utc(2026, 11, 26, 9, 30, 15, 500),
      );
    });
  });

  group('Discogs connection', () {
    setUp(() => store.seed());

    test('a started connection opens the Discogs link', () async {
      final client = make(
        (method, uri, headers, body, limit) async =>
            reply(201, 'discogs_connection_started.json'),
      );
      final url = await client.auth.beginAuthorization();
      expect(
        url.toString(),
        (fixture('discogs_connection_started.json')!
            as Map)['authorizationUrl'],
      );
      expect(jsonDecode(store.values['flow']!)['transactionId'], flowId);
    });

    for (final (status, outcome) in [
      ('pending', 'pending'),
      ('connected', 'connected'),
      ('canceled', 'canceled'),
    ]) {
      test('flow status "$status" is understood', () async {
        store.seedFlow();
        final client = make((method, uri, headers, body, limit) async {
          if (uri.path == '/v1/discogs/account') {
            return reply(200, 'discogs_account_connected.json');
          }
          return reply(200, 'discogs_connection_$status.json');
        });
        expect(await client.auth.authorizationStatus(), outcome);
      });
    }

    for (final status in ['expired', 'failed']) {
      test('flow status "$status" ends the attempt', () async {
        store.seedFlow();
        final client = make(
          (method, uri, headers, body, limit) async =>
              reply(200, 'discogs_connection_$status.json'),
        );
        await expectLater(
          client.auth.authorizationStatus(),
          throwsA(isA<DiscogsAuthenticationFailure>()),
        );
        expect(store.values['flow'], isNull);
      });
    }

    test('connected and not-connected accounts are read', () async {
      var name = 'discogs_account_connected.json';
      final client = make(
        (method, uri, headers, body, limit) async => reply(200, name),
      );
      final account = await client.api.account();
      expect(account!.id, 1234567);
      expect(account.username, 'crate_digger');

      name = 'discogs_account_not_connected.json';
      expect(await client.api.account(), isNull);
    });
  });

  group('Discogs catalog', () {
    setUp(() => store.seed());

    test('search results, including empty optional fields', () async {
      final client = make(
        (method, uri, headers, body, limit) async =>
            reply(200, 'discogs_search_page.json'),
      );
      final results = await client.api.searchReleases(
        artist: 'John Coltrane',
        title: 'Blue Train',
      );
      expect(results, hasLength(2));
      expect(results.first.releaseId, 249504);
      expect(results.first.formats, ['Vinyl', 'LP', 'Album', 'Mono']);
      expect(results.first.coverImageUrl, isNotNull);
      expect(results.last.artist, 'Björk');
      expect(results.last.year, isNull);
      expect(results.last.label, isNull);
      expect(results.last.country, isNull);
      expect(results.last.formats, isEmpty);
      expect(results.last.coverImageUrl, isNull);
    });

    test('barcode results, with the matched barcode', () async {
      final client = make(
        (method, uri, headers, body, limit) async =>
            reply(200, 'discogs_barcode_page.json'),
      );
      final results = await client.api.searchReleasesByBarcode(
        barcode: '0094636036326',
      );
      expect(results.single.title, 'Blue Train');
    });

    test('a collection page, including empty optional fields', () async {
      final client = make(
        (method, uri, headers, body, limit) async =>
            reply(200, 'discogs_collection_page.json'),
      );
      final page = await client.api.collectionFolderReleases(page: 2);
      expect((page.page, page.pages, page.totalItems), (2, 3, 250));
      expect(page.items.first.instanceId, 987654321);
      expect(page.items.last.year, isNull);
      expect(page.items.last.formats, isEmpty);
      expect(page.items.last.coverImageUrl, isNull);
    });

    test('a release with tracks', () async {
      final client = make(
        (method, uri, headers, body, limit) async =>
            reply(200, 'discogs_release.json'),
      );
      final release = await client.api.release(releaseId: 249504);
      expect(release.genres, ['Jazz']);
      expect(release.styles, ['Hard Bop']);
      expect(release.tracks, hasLength(3));
      expect(release.tracks[0].durationSeconds, 643);
      expect(release.tracks[1].title, 'Moment’s Notice');
      expect(release.tracks[1].durationSeconds, isNull);
      expect(release.tracks[2].position, isNull);
      expect(release.tracks[2].side, isNull);
    });

    test('a release with only the required fields', () async {
      final client = make(
        (method, uri, headers, body, limit) async =>
            reply(200, 'discogs_release_minimal.json'),
      );
      final release = await client.api.release(releaseId: 7);
      expect(release.artworkUrl, isNull);
      expect(release.tracks, isEmpty);
      expect(release.genres, isEmpty);
    });
  });

  group('errors', () {
    final errors = [
      for (final entry in fixture('error_codes.json')! as List)
        (status: entry['status'] as int, code: entry['code'] as String),
    ];

    for (final error in errors) {
      test(
        '${error.status} ${error.code} becomes a friendly failure',
        () async {
          store.seed();
          final client = make(
            (method, uri, headers, body, limit) async => BackendResponse(
              error.status,
              Uint8List.fromList(utf8.encode(jsonEncode({'code': error.code}))),
            ),
          );
          Object? thrown;
          try {
            await client.api.release(releaseId: 1);
          } on Object catch (e) {
            thrown = e;
          }
          expect(thrown, isA<DiscogsFailure>());
          final message = (thrown! as DiscogsFailure).message;
          expect(message, isNot(contains(error.code)));
          expect(message.trim(), isNotEmpty);

          if (const {
            'authentication_required',
            'discogs_connection_required',
            'discogs_connection_changed',
            'discogs_reconnect_required',
          }.contains(error.code)) {
            expect(thrown, isA<DiscogsAuthenticationFailure>());
          } else if (error.status == 429) {
            expect(thrown, isA<DiscogsRateLimitFailure>());
          } else if (error.status >= 500) {
            expect(thrown, isA<DiscogsNetworkFailure>());
          }
        },
      );
    }

    test('reconnect-required tells people how to fix it', () {
      final failure = backendFailure(
        const BackendError(409, 'discogs_reconnect_required', null),
      );
      expect(failure, isA<DiscogsAuthenticationFailure>());
      expect(failure.message, contains('disconnect Discogs'));
    });
  });
}
