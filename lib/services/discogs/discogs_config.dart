/// Public backend origin only. Discogs consumer credentials live on the server.
class DiscogsConfig {
  const DiscogsConfig({this.backendUrl = 'https://api.groovefolio.app'});
  final String backendUrl;
  bool get isConfigured {
    final uri = Uri.tryParse(backendUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.path.isEmpty || uri.path == '/');
  }

  Uri get origin {
    if (!isConfigured) {
      throw StateError('Invalid HTTPS backend origin');
    }
    return Uri.parse(backendUrl).replace(path: '');
  }

  // Legacy deep links are a hint to query the saved server transaction only.
  bool matchesCallback(Uri uri) =>
      uri.scheme == 'groovefolio' &&
      uri.host == 'discogs-auth' &&
      uri.path.isEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasPort;
  static const fromEnvironment = DiscogsConfig(
    backendUrl: String.fromEnvironment(
      'GROOVEFOLIO_API_ORIGIN',
      defaultValue: 'https://api.groovefolio.app',
    ),
  );
}
