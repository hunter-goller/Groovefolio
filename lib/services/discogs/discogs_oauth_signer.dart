import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

typedef DiscogsClock = DateTime Function();
typedef DiscogsNonceFactory = String Function();

class DiscogsOAuthSigner {
  DiscogsOAuthSigner({
    required this.consumerKey,
    required this.consumerSecret,
    DiscogsClock? clock,
    DiscogsNonceFactory? nonceFactory,
  }) : _clock = clock ?? DateTime.now,
       _nonceFactory = nonceFactory ?? _defaultNonce;

  final String consumerKey;
  final String consumerSecret;
  final DiscogsClock _clock;
  final DiscogsNonceFactory _nonceFactory;

  Map<String, String> authorizationParameters({
    required String method,
    required Uri uri,
    String? token,
    String? tokenSecret,
    String? callback,
    String? verifier,
    Map<String, String> additionalParameters = const {},
  }) {
    final oauth = <String, String>{
      'oauth_consumer_key': consumerKey,
      'oauth_nonce': _nonceFactory(),
      'oauth_signature_method': 'HMAC-SHA1',
      'oauth_timestamp': (_clock().toUtc().millisecondsSinceEpoch ~/ 1000)
          .toString(),
      'oauth_version': '1.0',
      'oauth_token': ?token,
      'oauth_callback': ?callback,
      'oauth_verifier': ?verifier,
    };

    // OAuth 1.0 signatures cover query parameters, OAuth protocol parameters,
    // and application/x-www-form-urlencoded body parameters. Keeping the body
    // parameters separate from [oauth] lets callers sign a parameter without
    // also duplicating it in the Authorization header.
    final parameters = <String, String>{
      ...uri.queryParameters,
      ...additionalParameters,
      ...oauth,
    };

    final entries = parameters.entries.toList()
      ..sort((a, b) {
        final key = _encode(a.key).compareTo(_encode(b.key));
        return key != 0 ? key : _encode(a.value).compareTo(_encode(b.value));
      });

    final parameterString = entries
        .map((e) => '${_encode(e.key)}=${_encode(e.value)}')
        .join('&');
    // OAuth signs the request URI without query or fragment delimiters.
    // Using uri.replace(query: '', fragment: '') produces a URI ending in
    // `?#`, which changes the signature and causes Discogs to reject it.
    final baseUri = Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
    final baseString =
        '${method.toUpperCase()}&${_encode(baseUri)}&${_encode(parameterString)}';
    final key = '${_encode(consumerSecret)}&${_encode(tokenSecret ?? '')}';

    oauth['oauth_signature'] = base64Encode(
      Hmac(sha1, utf8.encode(key)).convert(utf8.encode(baseString)).bytes,
    );
    return oauth;
  }

  String authorizationHeader(Map<String, String> oauth) {
    final entries = oauth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return 'OAuth ${entries.map((e) => '${_encode(e.key)}="${_encode(e.value)}"').join(', ')}';
  }

  static String _encode(String value) => Uri.encodeComponent(value)
      .replaceAll('!', '%21')
      .replaceAll("'", '%27')
      .replaceAll('(', '%28')
      .replaceAll(')', '%29')
      .replaceAll('*', '%2A');

  static String _defaultNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
