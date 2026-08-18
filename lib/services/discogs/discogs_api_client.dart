import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  static final _databaseSearchUri = Uri.parse(
    'https://api.discogs.com/database/search',
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
    final body = await _sendText('POST', _requestTokenUri, oauth);
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
    final body = await _sendText('POST', _accessTokenUri, oauth);
    final parsed = Uri.splitQueryString(body);
    final token = parsed['oauth_token'];
    final secret = parsed['oauth_token_secret'];
    if (token == null || secret == null) {
      throw const DiscogsApiFailure('Invalid Discogs access token response.');
    }
    return DiscogsOAuthCredentials(token: token, tokenSecret: secret);
  }

  Future<DiscogsAccount> identity(DiscogsOAuthCredentials credentials) async {
    final json = await _getJson(_identityUri, credentials);
    return DiscogsAccount(
      id: json['id'] as int,
      username: json['username'] as String,
      resourceUrl: json['resource_url'] as String?,
    );
  }

  Future<List<DiscogsReleaseSearchResult>> searchReleases({
    required DiscogsOAuthCredentials credentials,
    required String artist,
    required String title,
    int limit = 5,
  }) async {
    final uri = _databaseSearchUri.replace(
      queryParameters: {
        'type': 'release',
        'format': 'vinyl',
        'artist': artist.trim(),
        'release_title': title.trim(),
        'per_page': limit.clamp(1, 100).toString(),
        'page': '1',
      },
    );
    final json = await _getJson(uri, credentials);
    final results = json['results'];
    if (results is! List) return const [];

    return results
        .whereType<Map<String, dynamic>>()
        .map(discogsReleaseSearchResultFromJson)
        .whereType<DiscogsReleaseSearchResult>()
        .take(limit)
        .toList(growable: false);
  }

  Future<DiscogsCollectionPage> collectionFolderReleases({
    required DiscogsOAuthCredentials credentials,
    required String username,
    required int page,
    int perPage = 100,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw ArgumentError.value(
        username,
        'username',
        'Discogs username cannot be empty.',
      );
    }

    final uri = Uri(
      scheme: 'https',
      host: 'api.discogs.com',
      pathSegments: [
        'users',
        normalizedUsername,
        'collection',
        'folders',
        '0',
        'releases',
      ],
      queryParameters: {
        'page': page.clamp(1, 1000000).toString(),
        'per_page': perPage.clamp(1, 100).toString(),
      },
    );
    final json = await _getJson(uri, credentials);
    return discogsCollectionPageFromJson(json);
  }

  Future<DiscogsReleaseDetails> release({
    required DiscogsOAuthCredentials credentials,
    required int releaseId,
  }) async {
    final uri = Uri.parse('https://api.discogs.com/releases/$releaseId');
    final json = await _getJson(uri, credentials);
    return discogsReleaseDetailsFromJson(json, releaseId: releaseId);
  }

  Future<Uint8List> downloadImage({
    required DiscogsOAuthCredentials credentials,
    required String url,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw const DiscogsApiFailure('Discogs returned an invalid artwork URL.');
    }
    final oauth = _oauthFor('GET', uri, credentials);
    return _sendBytes('GET', uri, oauth);
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri,
    DiscogsOAuthCredentials credentials,
  ) async {
    final oauth = _oauthFor('GET', uri, credentials);
    final body = await _sendText('GET', uri, oauth);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const DiscogsApiFailure('Discogs returned an unexpected response.');
    }
    return decoded;
  }

  Map<String, String> _oauthFor(
    String method,
    Uri uri,
    DiscogsOAuthCredentials credentials,
  ) {
    _ensureConfigured();
    return _signer.authorizationParameters(
      method: method,
      uri: uri,
      token: credentials.token,
      tokenSecret: credentials.tokenSecret,
    );
  }

  Future<String> _sendText(
    String method,
    Uri uri,
    Map<String, String> oauth,
  ) async {
    final bytes = await _sendBytes(method, uri, oauth);
    return utf8.decode(bytes);
  }

  Future<Uint8List> _sendBytes(
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
      final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
        buffer.addAll(chunk);
        return buffer;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Uint8List.fromList(bytes);
      }
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
