import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_oauth_signer.dart';

void main() {
  late DiscogsOAuthSigner signer;

  setUp(() {
    signer = DiscogsOAuthSigner(
      consumerKey: 'key',
      consumerSecret: 'secret',
      clock: () =>
          DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      nonceFactory: () => 'nonce',
    );
  });

  test('builds deterministic OAuth fields', () {
    final values = signer.authorizationParameters(
      method: 'POST',
      uri: Uri.parse('https://api.discogs.com/oauth/request_token'),
      callback: 'groovefolio://discogs-auth',
    );

    expect(values['oauth_consumer_key'], 'key');
    expect(values['oauth_timestamp'], '1700000000');
    expect(values['oauth_nonce'], 'nonce');
    expect(values['oauth_signature'], '6T1I4Gr5ARlrRn7yR6rjMxMRBdo=');
  });

  test('signs form parameters without putting them in OAuth header fields', () {
    final values = signer.authorizationParameters(
      method: 'POST',
      uri: Uri.parse('https://api.discogs.com/oauth/request_token'),
      additionalParameters: const {
        'oauth_callback': 'groovefolio://discogs-auth',
      },
    );

    expect(values.containsKey('oauth_callback'), isFalse);
    expect(values['oauth_signature'], '6T1I4Gr5ARlrRn7yR6rjMxMRBdo=');
  });
}
