import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/backend/backend_transport.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

void main() {
  test(
    'a request can use a shorter timeout than the transport default',
    () async {
      final pending = Completer<BackendResponse>();
      final transport = BackendTransport(
        timeout: const Duration(seconds: 2),
        sender: (method, uri, headers, body, limit) => pending.future,
      );
      addTearDown(transport.close);
      final stopwatch = Stopwatch()..start();

      await expectLater(
        transport.send(
          'GET',
          Uri.parse('https://api.groovefolio.app/v1/discogs/account'),
          requestTimeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<DiscogsNetworkFailure>()),
      );

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    },
  );

  test('request bodies are sent as UTF-8 with a matching charset', () async {
    // A local plain-HTTP server stands in for the backend. The connection
    // factory hands the client a plain socket, so no TLS certificate is needed.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = Completer<(String?, List<int>)>();
    server.listen((request) async {
      final bytes = <int>[];
      await request.forEach(bytes.addAll);
      received.complete((request.headers.contentType?.toString(), bytes));
      request.response
        ..statusCode = 200
        ..write('{}');
      await request.response.close();
    });
    final client = HttpClient()
      ..findProxy = ((_) => 'DIRECT')
      ..connectionFactory = (uri, proxyHost, proxyPort) =>
          Socket.startConnect(InternetAddress.loopbackIPv4, server.port);
    final transport = BackendTransport(client: client);
    addTearDown(transport.close);
    const body = '{"artist":"Björk","title":"Homogenic — Sigur Rós 🎶"}';

    await transport.send(
      'POST',
      Uri.parse('https://api.groovefolio.app/v1/test'),
      body: body,
    );

    final (contentType, bytes) = await received.future;
    expect(contentType, 'application/json; charset=utf-8');
    expect(bytes, utf8.encode(body));
    expect(utf8.decode(bytes), body);
  });

  test('encodeBody uses UTF-8', () {
    expect(BackendTransport.encodeBody('é'), [0xC3, 0xA9]);
  });
}
