import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_oauth_signer.dart';

void main() {
  test('builds deterministic OAuth fields', () {
    final signer = DiscogsOAuthSigner(
      consumerKey: 'key',
      consumerSecret: 'secret',
      clock: () =>
          DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      nonceFactory: () => 'nonce',
    );

    final values = signer.authorizationParameters(
      method: 'POST',
      uri: Uri.parse('https://api.discogs.com/oauth/request_token'),
      callback: 'vinylapp://discogs-auth',
    );

    expect(values['oauth_consumer_key'], 'key');
    expect(values['oauth_timestamp'], '1700000000');
    expect(values['oauth_nonce'], 'nonce');
    expect(values['oauth_signature'], isNotEmpty);
  });
}
