class DiscogsConfig {
  const DiscogsConfig({
    required this.consumerKey,
    required this.consumerSecret,
    this.callbackUri = 'groovefolio://discogs-auth',
    this.userAgent = 'Groovefolio/0.1',
  });

  final String consumerKey;
  final String consumerSecret;
  final String callbackUri;
  final String userAgent;

  bool get isConfigured =>
      consumerKey.trim().isNotEmpty && consumerSecret.trim().isNotEmpty;

  Uri get callback => Uri.parse(callbackUri);

  bool matchesCallback(Uri uri) {
    final expected = callback;
    return uri.scheme == expected.scheme &&
        uri.host == expected.host &&
        uri.path == expected.path;
  }

  static const fromEnvironment = DiscogsConfig(
    consumerKey: String.fromEnvironment('DISCOGS_CONSUMER_KEY'),
    consumerSecret: String.fromEnvironment('DISCOGS_CONSUMER_SECRET'),
  );
}
