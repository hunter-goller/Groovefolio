// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_oauth_signer.dart';

List<String> discogsBarcodeSearchCandidates(String barcode) {
  final normalized = barcode.replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    throw ArgumentError.value(
      barcode,
      'barcode',
      'Discogs barcode cannot be empty.',
    );
  }

  final candidates = <String>[normalized];
  if (normalized.length == 13 && normalized.startsWith('0')) {
    candidates.add(normalized.substring(1));
  } else if (normalized.length == 12) {
    candidates.add('0$normalized');
  }

  return List<String>.unmodifiable(candidates.toSet());
}

class DiscogsHttpResponse {
  const DiscogsHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final Uint8List body;
  final Map<String, String> headers;
}

typedef DiscogsRequestSender =
    Future<DiscogsHttpResponse> Function(
      String method,
      Uri uri,
      Map<String, String> headers,
      int maxResponseBytes,
    );

typedef DiscogsDelay = Future<void> Function(Duration duration);

class DiscogsApiClient {
  DiscogsApiClient({
    required DiscogsConfig config,
    HttpClient? httpClient,
    DiscogsOAuthSigner? signer,
    DiscogsRequestSender? requestSender,
    DiscogsDelay? delay,
    Random? random,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _config = config,
       _httpClient = httpClient ?? HttpClient(),
       _signer =
           signer ??
           DiscogsOAuthSigner(
             consumerKey: config.consumerKey,
             consumerSecret: config.consumerSecret,
           ),
       _requestSender = requestSender,
       _delay = delay ?? ((duration) => Future<void>.delayed(duration)),
       _random = random ?? Random();

  final DiscogsConfig _config;
  final HttpClient _httpClient;
  final DiscogsOAuthSigner _signer;
  final DiscogsRequestSender? _requestSender;
  final DiscogsDelay _delay;
  final Random _random;
  final Duration requestTimeout;

  static const int _maxTextResponseBytes = 4 * 1024 * 1024;
  static const int _maxArtworkResponseBytes = 20 * 1024 * 1024;
  static const int _maxGetAttempts = 3;
  static const Set<String> _allowedArtworkHosts = {
    'i.discogs.com',
    'img.discogs.com',
    'api-img.discogs.com',
  };

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
    final id = json['id'];
    final username = json['username'];
    if (id is! int || username is! String || username.trim().isEmpty) {
      throw const DiscogsApiFailure(
        'Discogs returned an invalid identity response.',
      );
    }
    final resourceUrl = json['resource_url'];
    return DiscogsAccount(
      id: id,
      username: username.trim(),
      resourceUrl: resourceUrl is String && resourceUrl.trim().isNotEmpty
          ? resourceUrl.trim()
          : null,
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

  Future<List<DiscogsReleaseSearchResult>> searchReleasesByBarcode({
    required DiscogsOAuthCredentials credentials,
    required String barcode,
    int limit = 10,
  }) async {
    final candidates = discogsBarcodeSearchCandidates(barcode);

    for (final candidate in candidates) {
      final uri = _databaseSearchUri.replace(
        queryParameters: {
          'type': 'release',
          'format': 'vinyl',
          'barcode': candidate,
          'per_page': limit.clamp(1, 100).toString(),
          'page': '1',
        },
      );
      final json = await _getJson(uri, credentials);
      final results = json['results'];
      if (results is! List) continue;

      final parsed = results
          .whereType<Map<String, dynamic>>()
          .map(discogsReleaseSearchResultFromJson)
          .whereType<DiscogsReleaseSearchResult>()
          .take(limit)
          .toList(growable: false);
      if (parsed.isNotEmpty) return parsed;
    }

    return const [];
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
    _ensureConfigured();
    final uri = Uri.tryParse(url);
    if (!_isAllowedArtworkUri(uri)) {
      throw const DiscogsApiFailure(
        'Discogs returned an untrusted artwork URL.',
      );
    }

    // Discogs CDN artwork is fetched without OAuth. Never forward the user's
    // OAuth token/Authorization header to a host merely because an API response
    // supplied its URL.
    return _sendBytes(
      'GET',
      uri!,
      null,
      maxResponseBytes: _maxArtworkResponseBytes,
    );
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri,
    DiscogsOAuthCredentials credentials,
  ) async {
    final oauth = _oauthFor('GET', uri, credentials);
    final body = await _sendText('GET', uri, oauth);
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const DiscogsApiFailure(
          'Discogs returned an unexpected response.',
        );
      }
      return decoded;
    } on DiscogsFailure {
      rethrow;
    } on FormatException {
      throw const DiscogsApiFailure('Discogs returned malformed JSON.');
    }
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
    final bytes = await _sendBytes(
      method,
      uri,
      oauth,
      maxResponseBytes: _maxTextResponseBytes,
    );
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const DiscogsApiFailure('Discogs returned malformed text data.');
    }
  }

  Future<Uint8List> _sendBytes(
    String method,
    Uri uri,
    Map<String, String>? oauth, {
    required int maxResponseBytes,
  }) async {
    final normalizedMethod = method.toUpperCase();
    final maxAttempts = normalizedMethod == 'GET' ? _maxGetAttempts : 1;
    final headers = <String, String>{
      HttpHeaders.userAgentHeader: _config.userAgent,
      if (oauth != null)
        HttpHeaders.authorizationHeader: _signer.authorizationHeader(oauth),
    };

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      DiscogsHttpResponse response;
      try {
        final sender = _requestSender ?? _sendWithHttpClient;
        response = await sender(
          normalizedMethod,
          uri,
          headers,
          maxResponseBytes,
        ).timeout(requestTimeout);
      } on DiscogsFailure {
        rethrow;
      } on TimeoutException {
        if (attempt + 1 < maxAttempts) {
          await _delay(_retryDelay(attempt));
          continue;
        }
        throw const DiscogsNetworkFailure('Discogs request timed out.');
      } on SocketException {
        if (attempt + 1 < maxAttempts) {
          await _delay(_retryDelay(attempt));
          continue;
        }
        throw const DiscogsNetworkFailure('Could not reach Discogs.');
      } on HandshakeException {
        if (attempt + 1 < maxAttempts) {
          await _delay(_retryDelay(attempt));
          continue;
        }
        throw const DiscogsNetworkFailure(
          'Could not establish a secure connection to Discogs.',
        );
      } on HttpException {
        if (attempt + 1 < maxAttempts) {
          await _delay(_retryDelay(attempt));
          continue;
        }
        throw const DiscogsNetworkFailure('Discogs connection failed.');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw DiscogsAuthenticationFailure(
          'Discogs authorization failed (${response.statusCode}).',
        );
      }
      if (response.statusCode == 429) {
        final retryAfter = _retryAfter(response.headers);
        if (attempt + 1 < maxAttempts) {
          await _delay(retryAfter ?? _retryDelay(attempt));
          continue;
        }
        throw DiscogsRateLimitFailure(
          'Discogs rate limit reached. Try again shortly.',
          retryAfter: retryAfter,
        );
      }
      if (_isRetryableServerStatus(response.statusCode) &&
          attempt + 1 < maxAttempts) {
        await _delay(_retryDelay(attempt));
        continue;
      }
      throw DiscogsApiFailure(
        'Discogs request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    throw const DiscogsNetworkFailure('Discogs request failed.');
  }

  Future<DiscogsHttpResponse> _sendWithHttpClient(
    String method,
    Uri uri,
    Map<String, String> headers,
    int maxResponseBytes,
  ) async {
    final request = await _httpClient.openUrl(method, uri);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const DiscogsApiFailure(
          'Discogs response exceeded the allowed size.',
        );
      }
      bytes.addAll(chunk);
    }

    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name.toLowerCase()] = values.join(',');
    });

    return DiscogsHttpResponse(
      statusCode: response.statusCode,
      body: Uint8List.fromList(bytes),
      headers: responseHeaders,
    );
  }

  bool _isAllowedArtworkUri(Uri? uri) {
    if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;
    return _allowedArtworkHosts.contains(uri.host.toLowerCase());
  }

  bool _isRetryableServerStatus(int statusCode) {
    return statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  Duration _retryDelay(int attempt) {
    final exponentialMs = 400 * (1 << attempt);
    final jitterMs = _random.nextInt(201);
    return Duration(milliseconds: exponentialMs + jitterMs);
  }

  Duration? _retryAfter(Map<String, String> headers) {
    final raw = headers[HttpHeaders.retryAfterHeader]?.trim();
    if (raw == null || raw.isEmpty) return null;

    final seconds = int.tryParse(raw);
    if (seconds != null) {
      return _capRetryAfter(Duration(seconds: seconds < 0 ? 0 : seconds));
    }

    try {
      final target = HttpDate.parse(raw).toUtc();
      final duration = target.difference(DateTime.now().toUtc());
      return _capRetryAfter(duration.isNegative ? Duration.zero : duration);
    } catch (_) {
      return null;
    }
  }

  Duration _capRetryAfter(Duration value) {
    const maxDelay = Duration(seconds: 30);
    return value > maxDelay ? maxDelay : value;
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
