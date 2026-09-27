import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:vinyl_app/services/discogs/discogs_models.dart';

class BackendResponse {
  const BackendResponse(this.status, this.body, [this.headers = const {}]);
  final int status;
  final Uint8List body;
  final Map<String, String> headers;

  Map<String, dynamic> json() {
    try {
      final value = jsonDecode(utf8.decode(body));
      if (value is Map<String, dynamic>) {
        return value;
      }
    } on FormatException {
      // Never include response text (which may contain credentials) in errors.
    }
    throw const DiscogsApiFailure('The server returned an invalid response.');
  }
}

typedef BackendSender =
    Future<BackendResponse> Function(
      String method,
      Uri uri,
      Map<String, String> headers,
      String? body,
      int limit,
    );

class BackendError implements Exception {
  const BackendError(this.status, this.code, this.retryAfter);
  final int status;
  final String? code;
  final Duration? retryAfter;
  bool get invalidToken => status == 401 && code == 'authentication_required';
  @override
  String toString() => 'Backend request failed ($status).';
}

/// Bounded HTTPS transport. No redirects or automatic mutation retries.
class BackendTransport {
  BackendTransport({
    BackendSender? sender,
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
  }) : _sender = sender,
       _client = client ?? HttpClient();
  final BackendSender? _sender;
  final HttpClient _client;
  final Duration timeout;

  Future<BackendResponse> send(
    String method,
    Uri uri, {
    String? token,
    String? body,
    int limit = 4 * 1024 * 1024,
  }) async {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const DiscogsApiFailure('A secure server address is required.');
    }
    final headers = {
      'Accept': 'application/json',
      'User-Agent': 'Groovefolio/1.0',
      if (token != null) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    try {
      final response = await (_sender ?? _send)(
        method,
        uri,
        headers,
        body,
        limit,
      ).timeout(timeout);
      if (response.body.length > limit) {
        throw const DiscogsApiFailure('The server response was too large.');
      }
      if (response.status >= 200 && response.status < 300) {
        return response;
      }
      String? code;
      try {
        code = response.json()['code'] as String?;
      } catch (_) {
        /* Edge errors may be HTML. */
      }
      final retry = int.tryParse(response.headers['retry-after'] ?? '');
      throw BackendError(
        response.status,
        code,
        retry == null || retry < 0 ? null : Duration(seconds: retry),
      );
    } on TimeoutException {
      throw const DiscogsNetworkFailure(
        'The server took too long to respond. Try again.',
      );
    } on IOException {
      throw const DiscogsNetworkFailure(
        'Could not reach Groovefolio. Check your connection and try again.',
      );
    }
  }

  Future<BackendResponse> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
    int limit,
  ) async {
    HttpClientRequest? request;
    var expired = false;
    final timer = Timer(timeout, () {
      expired = true;
      request?.abort();
    });
    try {
      request = await _client.openUrl(method, uri);
      if (expired) {
        request.abort();
        throw TimeoutException('Request expired');
      }
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (body != null) {
        request.write(body);
      }
      final response = await request.close();
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (expired) {
          throw TimeoutException('Request expired');
        }
        if (bytes.length + chunk.length > limit) {
          request.abort();
          throw const DiscogsApiFailure('The server response was too large.');
        }
        bytes.add(chunk);
      }
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name.toLowerCase()] = values.join(',');
      });
      return BackendResponse(
        response.statusCode,
        bytes.takeBytes(),
        responseHeaders,
      );
    } finally {
      timer.cancel();
    }
  }

  void close() => _client.close(force: true);
}

DiscogsFailure backendFailure(BackendError error) {
  if (error.invalidToken) {
    return const DiscogsAuthenticationFailure(
      'Your connection expired. Connect Discogs again in Settings.',
    );
  }
  if (error.code == 'discogs_connection_required' ||
      error.code == 'discogs_connection_changed') {
    return const DiscogsAuthenticationFailure(
      'Connect Discogs again in Settings to continue.',
    );
  }
  if (error.status == 429) {
    return DiscogsRateLimitFailure(
      'Too many requests. Please wait before trying again.',
      retryAfter: error.retryAfter,
    );
  }
  if (error.status >= 500) {
    return const DiscogsNetworkFailure(
      'Discogs is temporarily unavailable. Try again shortly.',
    );
  }
  if (error.status == 403) {
    return const DiscogsApiFailure(
      'The request was blocked. Please try again later.',
    );
  }
  return DiscogsApiFailure(
    'The request could not be completed. Try again.',
    statusCode: error.status,
  );
}
