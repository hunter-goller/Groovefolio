import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';

void main() {
  const config = DiscogsConfig(consumerKey: 'key', consumerSecret: 'secret');

  test('matches configured OAuth callback URI', () {
    expect(
      config.matchesCallback(
        Uri.parse(
          'groovefolio://discogs-auth?oauth_token=token&oauth_verifier=verifier',
        ),
      ),
      isTrue,
    );
  });

  test('rejects unrelated custom-scheme URI', () {
    expect(config.matchesCallback(Uri.parse('groovefolio://other')), isFalse);
  });
}
