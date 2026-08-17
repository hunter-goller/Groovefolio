import 'dart:convert';
import 'dart:io';

import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_oauth_signer.dart';

class DiscogsApiClient {
  DiscogsApiClient({
    required DiscogsConfig config,
    HttpClient? httpClient,
    DiscogsOAuthSigner? signer,
  }) : _config = config,
       _httpClient = httpClient ?? HttpClient(),
       _signer =
           signer ??
           DiscogsOAuthSigner(
             consumerKey: config.consumerKey,
             consumerSecret: config.consumerSecret,
           );

  final DiscogsConfig _config;
  final HttpClient _httpClient;
  final DiscogsOAuthSigner _signer;

  static final _requestTokenUri = Uri.parse(
    'https://api.discogs.com/oauth/request_token',
  );
  static final _accessTokenUri = Uri.parse(
    'https://api.discogs.com/oauth/access_token',
  );
  static final _identityUri = Uri.parse(
    'https://api.discogs.com/oauth/identity',
  );

  Uri authorizationUri(String token) => Uri.parse(
    'https://www.discogs.com/oauth/authorize',
  ).replace(queryParameters: {'oauth_token': token});

  Future<DiscogsRequestToken> requestToken() async {
    _ensureConfigured();

    // Discogs' OAuth request-token flow expects oauth_callback to be supplied
    // during this POST. Send it as an application/x-www-form-urlencoded body
    // parameter and include that same parameter in the OAuth signature.
    final formBody = <String, String>{'oauth_callback': _config.callbackUri};
    final oauth = _signer.authorizationParameters(
      method: 'POST',
      uri: _requestTokenUri,
      additionalParameters: formBody,
    );
    final body = await _send(
      'POST',
      _requestTokenUri,
      oauth,
      formBody: formBody,
    );
    final parsed = Uri.splitQueryString(body);
    final token = parsed['oauth_token'];
    final secret = parsed['oauth_token_secret'];
    if (token == null || secret == null) {
      throw const DiscogsApiFailure('Invalid Discogs request token response.');
    }
    return DiscogsRequestToken(token: token, tokenSecret: secret);
  }

  Future<DiscogsOAuthCredentials> exchangeVerifier({
    required DiscogsRequestToken requestToken,
    required String verifier,
  }) async {
    final oauth = _signer.authorizationParameters(
      method: 'POST',
      uri: _accessTokenUri,
      token: requestToken.token,
      tokenSecret: requestToken.tokenSecret,
      verifier: verifier,
    );
    final body = await _send('POST', _accessTokenUri, oauth);
    final parsed = Uri.splitQueryString(body);
    final token = parsed['oauth_token'];
    final secret = parsed['oauth_token_secret'];
    if (token == null || secret == null) {
      throw const DiscogsApiFailure('Invalid Discogs access token response.');
    }
    return DiscogsOAuthCredentials(token: token, tokenSecret: secret);
  }

  Future<DiscogsAccount> identity(DiscogsOAuthCredentials credentials) async {
    final oauth = _signer.authorizationParameters(
      method: 'GET',
      uri: _identityUri,
      token: credentials.token,
      tokenSecret: credentials.tokenSecret,
    );
    final body = await _send('GET', _identityUri, oauth);
    final json = jsonDecode(body) as Map<String, dynamic>;
    return DiscogsAccount(
      id: json['id'] as int,
      username: json['username'] as String,
      resourceUrl: json['resource_url'] as String?,
    );
  }

  Future<String> _send(
    String method,
    Uri uri,
    Map<String, String> oauth, {
    Map<String, String>? formBody,
  }) async {
    try {
      final request = await _httpClient.openUrl(method, uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        _signer.authorizationHeader(oauth),
      );
      request.headers.set(HttpHeaders.userAgentHeader, _config.userAgent);

      if (formBody != null) {
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/x-www-form-urlencoded',
        );
        request.write(Uri(queryParameters: formBody).query);
      }

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode >= 200 && response.statusCode < 300) return body;
      if (response.statusCode == 401 || response.statusCode == 403) {
        final detail = _safeResponseDetail(body);
        throw DiscogsAuthenticationFailure(
          detail == null
              ? 'Discogs authorization failed (${response.statusCode}).'
              : 'Discogs authorization failed (${response.statusCode}): $detail',
        );
      }
      if (response.statusCode == 429) {
        throw const DiscogsRateLimitFailure(
          'Discogs rate limit reached. Try again shortly.',
        );
      }
      final detail = _safeResponseDetail(body);
      throw DiscogsApiFailure(
        detail == null
            ? 'Discogs request failed (${response.statusCode}).'
            : 'Discogs request failed (${response.statusCode}): $detail',
        statusCode: response.statusCode,
      );
    } on DiscogsFailure {
      rethrow;
    } on SocketException catch (e) {
      throw DiscogsNetworkFailure('Could not reach Discogs: $e');
    }
  }

  String? _safeResponseDetail(String body) {
    if (body.trim().isEmpty) return null;

    String detail;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        detail = decoded['message'] as String;
      } else {
        detail = body;
      }
    } catch (_) {
      detail = body;
    }

    detail = detail.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_config.consumerKey.isNotEmpty) {
      detail = detail.replaceAll(_config.consumerKey, '[redacted]');
    }
    if (_config.consumerSecret.isNotEmpty) {
      detail = detail.replaceAll(_config.consumerSecret, '[redacted]');
    }
    if (detail.length > 240) {
      detail = '${detail.substring(0, 240)}…';
    }
    return detail.isEmpty ? null : detail;
  }

  void close() => _httpClient.close(force: true);

  void _ensureConfigured() {
    if (!_config.isConfigured) {
      throw const DiscogsAuthenticationFailure(
        'Discogs application credentials are not configured.',
      );
    }
  }
}
