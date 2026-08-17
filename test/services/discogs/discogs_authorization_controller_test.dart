import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_auth_service.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';

void main() {
  late _FakeDiscogsAuthService authService;
  late ProviderContainer container;

  setUp(() {
    authService = _FakeDiscogsAuthService();
    container = ProviderContainer(
      overrides: [
        discogsConfigProvider.overrideWithValue(
          const DiscogsConfig(consumerKey: 'key', consumerSecret: 'secret'),
        ),
        discogsAuthServiceProvider.overrideWithValue(authService),
      ],
    );
  });

  tearDown(() => container.dispose());

  test(
    'connect launches browser authorization and waits for callback',
    () async {
      final controller = container.read(
        discogsAuthorizationControllerProvider.notifier,
      );

      await controller.connect();

      expect(authService.authorizationLaunched, isTrue);
      expect(
        container.read(discogsAuthorizationControllerProvider).status,
        DiscogsAuthorizationStatus.awaitingCallback,
      );
    },
  );

  test('valid callback exchanges verifier and returns to idle', () async {
    final controller = container.read(
      discogsAuthorizationControllerProvider.notifier,
    );

    final handled = await controller.handleCallback(
      Uri.parse(
        'groovefolio://discogs-auth?oauth_token=request-token&oauth_verifier=123456',
      ),
    );

    expect(handled, isTrue);
    expect(authService.completedOauthToken, 'request-token');
    expect(authService.completedVerifier, '123456');
    expect(
      container.read(discogsAuthorizationControllerProvider).status,
      DiscogsAuthorizationStatus.idle,
    );
  });

  test('callback rejects missing verifier with typed failure', () async {
    final controller = container.read(
      discogsAuthorizationControllerProvider.notifier,
    );

    final handled = await controller.handleCallback(
      Uri.parse('groovefolio://discogs-auth?oauth_token=request-token'),
    );

    final state = container.read(discogsAuthorizationControllerProvider);
    expect(handled, isTrue);
    expect(state.status, DiscogsAuthorizationStatus.failed);
    expect(state.failure, isA<DiscogsAuthenticationFailure>());
  });

  test('unrelated deep link is ignored', () async {
    final controller = container.read(
      discogsAuthorizationControllerProvider.notifier,
    );

    final handled = await controller.handleCallback(
      Uri.parse('groovefolio://something-else?oauth_token=x&oauth_verifier=y'),
    );

    expect(handled, isFalse);
    expect(authService.completedOauthToken, isNull);
  });

  test('cancel clears pending authorization', () async {
    final controller = container.read(
      discogsAuthorizationControllerProvider.notifier,
    );

    await controller.connect();
    await controller.cancelAuthorization();

    expect(authService.authorizationCancelled, isTrue);
    expect(
      container.read(discogsAuthorizationControllerProvider).status,
      DiscogsAuthorizationStatus.idle,
    );
  });
}

class _FakeDiscogsAuthService implements DiscogsAuthService {
  bool authorizationLaunched = false;
  bool authorizationCancelled = false;
  bool disconnected = false;
  String? completedOauthToken;
  String? completedVerifier;

  @override
  Future<DiscogsAccount?> currentAccount() async => null;

  @override
  Future<Uri> beginAuthorization() async => Uri.parse(
    'https://www.discogs.com/oauth/authorize?oauth_token=request-token',
  );

  @override
  Future<void> launchAuthorization() async {
    authorizationLaunched = true;
  }

  @override
  Future<DiscogsAccount> completeAuthorization({
    required String oauthToken,
    required String verifier,
  }) async {
    completedOauthToken = oauthToken;
    completedVerifier = verifier;
    return const DiscogsAccount(id: 7, username: 'hunter');
  }

  @override
  Future<void> cancelAuthorization() async {
    authorizationCancelled = true;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }
}
