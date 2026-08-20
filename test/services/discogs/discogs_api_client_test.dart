import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

void main() {
  const config = DiscogsConfig(
    consumerKey: 'consumer-key',
    consumerSecret: 'consumer-secret',
    userAgent: 'Groovefolio/test',
  );
  const credentials = DiscogsOAuthCredentials(
    token: 'access-token',
    tokenSecret: 'access-secret',
  );

  test('identity converts malformed JSON into a typed API failure', () async {
    final client = DiscogsApiClient(
      config: config,
      requestSender: (method, uri, headers, maxBytes) async =>
          DiscogsHttpResponse(
            statusCode: 200,
            body: Uint8List.fromList(utf8.encode('{not-json')),
          ),
    );
    addTearDown(client.close);

    await expectLater(
      client.identity(credentials),
      throwsA(
        isA<DiscogsApiFailure>().having(
          (failure) => failure.message,
          'message',
          contains('malformed JSON'),
        ),
      ),
    );
  });

  test(
    'identity rejects missing required fields with a typed failure',
    () async {
      final client = DiscogsApiClient(
        config: config,
        requestSender: (method, uri, headers, maxBytes) async =>
            DiscogsHttpResponse(
              statusCode: 200,
              body: Uint8List.fromList(utf8.encode('{"username":"hunter"}')),
            ),
      );
      addTearDown(client.close);

      await expectLater(
        client.identity(credentials),
        throwsA(isA<DiscogsApiFailure>()),
      );
    },
  );

  test('GET honors Retry-After and retries a 429 before succeeding', () async {
    var requests = 0;
    final delays = <Duration>[];
    final client = DiscogsApiClient(
      config: config,
      random: Random(1),
      delay: (duration) async => delays.add(duration),
      requestSender: (method, uri, headers, maxBytes) async {
        requests += 1;
        if (requests == 1) {
          return DiscogsHttpResponse(
            statusCode: 429,
            body: Uint8List(0),
            headers: {HttpHeaders.retryAfterHeader: '2'},
          );
        }
        return DiscogsHttpResponse(
          statusCode: 200,
          body: Uint8List.fromList(utf8.encode('{"id":1,"username":"hunter"}')),
        );
      },
    );
    addTearDown(client.close);

    final account = await client.identity(credentials);

    expect(account.username, 'hunter');
    expect(requests, 2);
    expect(delays, [const Duration(seconds: 2)]);
  });

  test('401 is typed and is not retried', () async {
    var requests = 0;
    final client = DiscogsApiClient(
      config: config,
      delay: (_) async {},
      requestSender: (method, uri, headers, maxBytes) async {
        requests += 1;
        return DiscogsHttpResponse(statusCode: 401, body: Uint8List(0));
      },
    );
    addTearDown(client.close);

    await expectLater(
      client.identity(credentials),
      throwsA(isA<DiscogsAuthenticationFailure>()),
    );
    expect(requests, 1);
  });

  test('request timeout becomes a typed network failure', () async {
    final client = DiscogsApiClient(
      config: config,
      requestTimeout: const Duration(milliseconds: 2),
      delay: (_) async {},
      requestSender: (method, uri, headers, maxBytes) =>
          Completer<DiscogsHttpResponse>().future,
    );
    addTearDown(client.close);

    await expectLater(
      client.identity(credentials),
      throwsA(isA<DiscogsNetworkFailure>()),
    );
  });

  test('barcode search retries UPC-A as zero-prefixed EAN-13', () async {
    final requestedBarcodes = <String>[];
    final client = DiscogsApiClient(
      config: config,
      requestSender: (method, uri, headers, maxBytes) async {
        requestedBarcodes.add(uri.queryParameters['barcode'] ?? '');
        final hasMatch = uri.queryParameters['barcode'] == '0074643377512';
        final body = hasMatch
            ? jsonEncode({
                'results': [
                  {
                    'id': 456,
                    'title': 'John Coltrane - Blue Train',
                    'format': ['Vinyl', 'LP'],
                  },
                ],
              })
            : jsonEncode({'results': <Object>[]});
        return DiscogsHttpResponse(
          statusCode: 200,
          body: Uint8List.fromList(utf8.encode(body)),
        );
      },
    );
    addTearDown(client.close);

    final results = await client.searchReleasesByBarcode(
      credentials: credentials,
      barcode: '074643377512',
    );

    expect(requestedBarcodes, ['074643377512', '0074643377512']);
    expect(results, hasLength(1));
    expect(results.single.releaseId, 456);
    expect(results.single.artist, 'John Coltrane');
    expect(results.single.title, 'Blue Train');
  });

  test('artwork rejects non-HTTPS and non-Discogs image hosts', () async {
    var requests = 0;
    final client = DiscogsApiClient(
      config: config,
      requestSender: (method, uri, headers, maxBytes) async {
        requests += 1;
        return DiscogsHttpResponse(statusCode: 200, body: Uint8List(0));
      },
    );
    addTearDown(client.close);

    await expectLater(
      client.downloadImage(
        credentials: credentials,
        url: 'https://example.test/cover.jpg',
      ),
      throwsA(isA<DiscogsApiFailure>()),
    );
    await expectLater(
      client.downloadImage(
        credentials: credentials,
        url: 'http://i.discogs.com/cover.jpg',
      ),
      throwsA(isA<DiscogsApiFailure>()),
    );
    expect(requests, 0);
  });

  test(
    'trusted Discogs artwork is fetched without OAuth Authorization',
    () async {
      Map<String, String>? sentHeaders;
      final client = DiscogsApiClient(
        config: config,
        requestSender: (method, uri, headers, maxBytes) async {
          sentHeaders = Map.of(headers);
          return DiscogsHttpResponse(
            statusCode: 200,
            body: Uint8List.fromList([1, 2, 3]),
          );
        },
      );
      addTearDown(client.close);

      final bytes = await client.downloadImage(
        credentials: credentials,
        url: 'https://i.discogs.com/example/cover.jpg',
      );

      expect(bytes, [1, 2, 3]);
      expect(sentHeaders, isNotNull);
      expect(sentHeaders, isNot(contains(HttpHeaders.authorizationHeader)));
      expect(sentHeaders?[HttpHeaders.userAgentHeader], 'Groovefolio/test');
    },
  );
}
