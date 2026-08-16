class DiscogsConfig {
  const DiscogsConfig({
    required this.consumerKey,
    required this.consumerSecret,
    this.callbackUri = 'vinylapp://discogs-auth',
    this.userAgent = 'VinylApp/0.1',
  });

  final String consumerKey;
  final String consumerSecret;
  final String callbackUri;
  final String userAgent;

  bool get isConfigured =>
      consumerKey.trim().isNotEmpty && consumerSecret.trim().isNotEmpty;

  static const fromEnvironment = DiscogsConfig(
    consumerKey: String.fromEnvironment('DISCOGS_CONSUMER_KEY'),
    consumerSecret: String.fromEnvironment('DISCOGS_CONSUMER_SECRET'),
  );
}
