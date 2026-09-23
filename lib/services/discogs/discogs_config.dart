/// Configuration for the app's current direct Discogs integration.
///
/// [fromEnvironment] is compiled into a mobile build. A consumer secret in
/// an APK is extractable, so this is development configuration until the
/// production credential strategy and Flutter cutover are complete.
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

  /// Accepts only the registered scheme, host, and path; OAuth parameters
  /// in the query are validated separately by the authorization controller.
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
