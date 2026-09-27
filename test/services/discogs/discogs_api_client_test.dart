import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/backend/backend_transport.dart';
import 'package:vinyl_app/services/backend/installation_session.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import '../backend/backend_test_support.dart';

void main() {
  DiscogsApiClient make(BackendSender sender) {
    final store = MemoryBackendStore()..seed();
    final transport = BackendTransport(sender: sender);
    addTearDown(transport.close);
    return DiscogsApiClient(
      InstallationSession(
        origin: Uri.parse('https://api.groovefolio.app'),
        store: store,
        transport: transport,
        now: () => fixedNow,
      ),
      transport,
    );
  }

  test(
    'account uses installation bearer at the fixed backend origin',
    () async {
      final api = make((method, uri, headers, body, limit) async {
        expect(
          uri.toString(),
          'https://api.groovefolio.app/v1/discogs/account',
        );
        expect(headers['Authorization'], 'Bearer $oldToken');
        expect(body, isNull);
        return response(200, {
          'connected': true,
          'discogsId': 7,
          'username': 'listener',
        });
      });
      expect((await api.account())!.username, 'listener');
    },
  );
  test(
    'normalized search, barcode, release and collection contracts are mapped',
    () async {
      final paths = <String>[];
      final item = {
        'releaseId': 12,
        'instanceId': 34,
        'title': 'Blue Train',
        'artist': 'John Coltrane',
        'year': 1957,
        'label': 'Blue Note',
        'country': 'US',
        'formats': ['Vinyl', 'LP'],
        'coverImageUrl': null,
      };
      final api = make((method, uri, headers, body, limit) async {
        paths.add(uri.path);
        expect(headers['Authorization'], 'Bearer $oldToken');
        expect(uri.queryParameters.containsKey('username'), isFalse);
        if (uri.path.endsWith('/releases/12')) {
          return response(200, {
            ...item,
            'genres': ['Jazz'],
            'styles': ['Hard Bop'],
            'artworkUrl': null,
            'tracks': [
              {
                'title': 'Blue Train',
                'sequence': 0,
                'position': 'A1',
                'side': 'A',
                'durationSeconds': null,
              },
            ],
          });
        }
        return response(200, {
          'items': [item],
          'page': 1,
          'pages': 2,
          'totalItems': 101,
        });
      });
      expect(
        (await api.searchReleases(
          artist: 'John Coltrane',
          title: 'Blue Train',
        )).single.title,
        'Blue Train',
      );
      expect(
        (await api.searchReleasesByBarcode(
          barcode: '074643377512',
        )).single.releaseId,
        12,
      );
      expect((await api.release(releaseId: 12)).tracks.single.side, 'A');
      final collection = await api.collectionFolderReleases(page: 1);
      expect(collection.items.single.instanceId, 34);
      expect(collection.hasNextPage, isTrue);
      expect(paths, [
        '/v1/discogs/search',
        '/v1/discogs/barcode/074643377512',
        '/v1/discogs/releases/12',
        '/v1/discogs/collection',
      ]);
    },
  );
  test('malformed JSON is a typed failure without response text', () async {
    final api = make(
      (method, uri, headers, body, limit) async => BackendResponse(
        200,
        Uint8List.fromList(utf8.encode('secret-malformed-json')),
      ),
    );
    await expectLater(api.account(), throwsA(isA<DiscogsApiFailure>()));
  });
  test(
    'artwork has no bearer and rejects arbitrary hosts, ports and schemes',
    () async {
      var calls = 0;
      final api = make((method, uri, headers, body, limit) async {
        calls++;
        expect(headers.containsKey('Authorization'), isFalse);
        return BackendResponse(200, Uint8List.fromList([1, 2]));
      });
      for (final url in [
        'http://i.discogs.com/x',
        'https://evil.example/x',
        'https://i.discogs.com:8443/x',
        'https://user@i.discogs.com/x',
        'https://i.discogs.com.evil.example/x',
      ]) {
        await expectLater(
          api.downloadImage(url: url),
          throwsA(isA<DiscogsApiFailure>()),
        );
      }
      expect(calls, 0);
      expect(await api.downloadImage(url: 'https://i.discogs.com/x'), [1, 2]);
      expect(calls, 1);
    },
  );
  test(
    'redirects and HTML edge failures do not retry or erase the bearer',
    () async {
      var calls = 0;
      final api = make((method, uri, headers, body, limit) async {
        calls++;
        return response(302, null, {'location': 'https://evil.example/'});
      });
      await expectLater(api.account(), throwsA(isA<DiscogsApiFailure>()));
      expect(calls, 1);
      expect(await api.session.hasSession(), isTrue);
    },
  );
  test(
    'rate limit exposes Retry-After without tight automatic retries',
    () async {
      var calls = 0;
      final api = make((method, uri, headers, body, limit) async {
        calls++;
        return response(429, null, {'retry-after': '60'});
      });
      await expectLater(
        api.account(),
        throwsA(
          isA<DiscogsRateLimitFailure>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 60),
          ),
        ),
      );
      expect(calls, 1);
    },
  );
}
