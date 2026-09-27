import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';

void main() {
  test(
    'default configuration uses public HTTPS API without consumer secrets',
    () {
      const config = DiscogsConfig();
      expect(config.isConfigured, isTrue);
      expect(config.origin.toString(), 'https://api.groovefolio.app');
    },
  );
  test('rejects credentials, paths, query strings and insecure origins', () {
    for (final value in [
      'http://api.groovefolio.app',
      'https://user@api.groovefolio.app',
      'https://api.groovefolio.app/path',
      'https://api.groovefolio.app?token=x',
      'https://api.groovefolio.app#x',
    ]) {
      expect(DiscogsConfig(backendUrl: value).isConfigured, isFalse);
    }
  });
  test('only registered Discogs hint links match', () {
    const config = DiscogsConfig();
    expect(
      config.matchesCallback(Uri.parse('groovefolio://discogs-auth')),
      isTrue,
    );
    for (final uri in [
      'groovefolio://album/1',
      'https://discogs-auth',
      'groovefolio://user@discogs-auth',
      'groovefolio://discogs-auth/path',
    ]) {
      expect(config.matchesCallback(Uri.parse(uri)), isFalse);
    }
  });
}
