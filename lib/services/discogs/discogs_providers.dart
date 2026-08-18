import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_auth_service.dart';
import 'package:vinyl_app/services/discogs/discogs_catalog_service.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_credential_store.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

final discogsConfigProvider = Provider<DiscogsConfig>((ref) {
  return DiscogsConfig.fromEnvironment;
});

final discogsCredentialStoreProvider = Provider<DiscogsCredentialStore>((ref) {
  return SecureDiscogsCredentialStore();
});

final discogsApiClientProvider = Provider<DiscogsApiClient>((ref) {
  final client = DiscogsApiClient(config: ref.watch(discogsConfigProvider));
  ref.onDispose(client.close);
  return client;
});

final discogsAuthServiceProvider = Provider<DiscogsAuthService>((ref) {
  return DiscogsAuthService(
    apiClient: ref.watch(discogsApiClientProvider),
    credentialStore: ref.watch(discogsCredentialStoreProvider),
  );
});

final discogsCatalogServiceProvider = Provider<DiscogsCatalogService>((ref) {
  return DefaultDiscogsCatalogService(
    ref.watch(discogsApiClientProvider),
    ref.watch(discogsCredentialStoreProvider),
  );
});

final discogsAccountProvider = FutureProvider.autoDispose<DiscogsAccount?>((
  ref,
) {
  return ref.watch(discogsAuthServiceProvider).currentAccount();
});

final discogsAppLinksProvider = Provider<AppLinks>((ref) => AppLinks());

/// The AppLinks singleton is created during main() bootstrap, before database
/// initialization, so the OAuth callback is retained for both cold-start and
/// warm-app launches.
final discogsIncomingUriProvider = StreamProvider<Uri>((ref) {
  return ref.watch(discogsAppLinksProvider).uriLinkStream;
});

/// Lets widget tests opt out of platform deep-link registration without
/// changing production behavior.
final discogsDeepLinksEnabledProvider = Provider<bool>((ref) => true);

enum DiscogsAuthorizationStatus {
  idle,
  awaitingCallback,
  completing,
  disconnecting,
  failed,
}

class DiscogsAuthorizationState {
  const DiscogsAuthorizationState._({required this.status, this.failure});

  const DiscogsAuthorizationState.idle()
    : this._(status: DiscogsAuthorizationStatus.idle);

  const DiscogsAuthorizationState.awaitingCallback()
    : this._(status: DiscogsAuthorizationStatus.awaitingCallback);

  const DiscogsAuthorizationState.completing()
    : this._(status: DiscogsAuthorizationStatus.completing);

  const DiscogsAuthorizationState.disconnecting()
    : this._(status: DiscogsAuthorizationStatus.disconnecting);

  const DiscogsAuthorizationState.failed(DiscogsFailure failure)
    : this._(status: DiscogsAuthorizationStatus.failed, failure: failure);

  final DiscogsAuthorizationStatus status;
  final DiscogsFailure? failure;

  bool get isBusy =>
      status == DiscogsAuthorizationStatus.awaitingCallback ||
      status == DiscogsAuthorizationStatus.completing ||
      status == DiscogsAuthorizationStatus.disconnecting;

  bool get isAwaitingCallback =>
      status == DiscogsAuthorizationStatus.awaitingCallback;
}

class DiscogsAuthorizationController
    extends Notifier<DiscogsAuthorizationState> {
  @override
  DiscogsAuthorizationState build() => const DiscogsAuthorizationState.idle();

  Future<void> connect() async {
    if (state.isBusy) return;

    final config = ref.read(discogsConfigProvider);
    if (!config.isConfigured) {
      state = const DiscogsAuthorizationState.failed(
        DiscogsAuthenticationFailure(
          'Discogs application credentials are not configured for this build.',
        ),
      );
      return;
    }

    state = const DiscogsAuthorizationState.awaitingCallback();
    try {
      await ref.read(discogsAuthServiceProvider).launchAuthorization();
    } catch (error) {
      state = DiscogsAuthorizationState.failed(_typedFailure(error));
    }
  }

  /// Returns true when [uri] belongs to Groovefolio's Discogs callback,
  /// regardless of whether the callback succeeds. This lets the root app route
  /// the user back to Settings where success or failure can be shown.
  Future<bool> handleCallback(Uri uri) async {
    final config = ref.read(discogsConfigProvider);
    if (!config.matchesCallback(uri)) return false;

    final oauthToken = uri.queryParameters['oauth_token']?.trim();
    final verifier = uri.queryParameters['oauth_verifier']?.trim();
    if (oauthToken == null ||
        oauthToken.isEmpty ||
        verifier == null ||
        verifier.isEmpty) {
      state = const DiscogsAuthorizationState.failed(
        DiscogsAuthenticationFailure(
          'Discogs returned an incomplete authorization callback.',
        ),
      );
      return true;
    }

    state = const DiscogsAuthorizationState.completing();
    try {
      await ref
          .read(discogsAuthServiceProvider)
          .completeAuthorization(oauthToken: oauthToken, verifier: verifier);
      ref.invalidate(discogsAccountProvider);
      state = const DiscogsAuthorizationState.idle();
    } catch (error) {
      ref.invalidate(discogsAccountProvider);
      state = DiscogsAuthorizationState.failed(_typedFailure(error));
    }
    return true;
  }

  Future<void> cancelAuthorization() async {
    try {
      await ref.read(discogsAuthServiceProvider).cancelAuthorization();
      state = const DiscogsAuthorizationState.idle();
    } catch (error) {
      state = DiscogsAuthorizationState.failed(_typedFailure(error));
    }
  }

  Future<void> disconnect() async {
    if (state.isBusy) return;

    state = const DiscogsAuthorizationState.disconnecting();
    try {
      await ref.read(discogsAuthServiceProvider).disconnect();
      ref.invalidate(discogsAccountProvider);
      state = const DiscogsAuthorizationState.idle();
    } catch (error) {
      state = DiscogsAuthorizationState.failed(_typedFailure(error));
    }
  }

  void clearFailure() {
    state = const DiscogsAuthorizationState.idle();
  }

  DiscogsFailure _typedFailure(Object error) {
    if (error is DiscogsFailure) return error;
    return const DiscogsApiFailure(
      'The Discogs connection could not be updated. Try again.',
    );
  }
}

final discogsAuthorizationControllerProvider =
    NotifierProvider<DiscogsAuthorizationController, DiscogsAuthorizationState>(
      DiscogsAuthorizationController.new,
    );
