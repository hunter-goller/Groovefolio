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
    final oauth = _signer.authorizationParameters(
      method: 'POST',
      uri: _requestTokenUri,
      callback: _config.callbackUri,
    );
    final body = await _send('POST', _requestTokenUri, oauth);
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
    Map<String, String> oauth,
  ) async {
    try {
      final request = await _httpClient.openUrl(method, uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        _signer.authorizationHeader(oauth),
      );
      request.headers.set(HttpHeaders.userAgentHeader, _config.userAgent);
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode >= 200 && response.statusCode < 300) return body;
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw DiscogsAuthenticationFailure(
          'Discogs authorization failed (${response.statusCode}).',
        );
      }
      if (response.statusCode == 429) {
        throw const DiscogsRateLimitFailure(
          'Discogs rate limit reached. Try again shortly.',
        );
      }
      throw DiscogsApiFailure(
        'Discogs request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } on DiscogsFailure {
      rethrow;
    } on SocketException catch (e) {
      throw DiscogsNetworkFailure('Could not reach Discogs: $e');
    }
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
