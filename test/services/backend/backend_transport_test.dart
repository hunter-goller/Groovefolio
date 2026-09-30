import 'dart:async';

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
}
