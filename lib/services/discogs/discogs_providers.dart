import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/services/backend/backend_store.dart';
import 'package:vinyl_app/services/backend/backend_transport.dart';
import 'package:vinyl_app/services/backend/installation_session.dart';
import 'package:vinyl_app/services/discogs/discogs_api_client.dart';
import 'package:vinyl_app/services/discogs/discogs_auth_service.dart';
import 'package:vinyl_app/services/discogs/discogs_catalog_service.dart';
import 'package:vinyl_app/services/discogs/discogs_config.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';

final discogsConfigProvider = Provider<DiscogsConfig>((ref) {
  return DiscogsConfig.fromEnvironment;
});

final backendStoreProvider = Provider<BackendStore>((ref) {
  return SecureBackendStore(ref.watch(discogsConfigProvider).origin.toString());
});
final backendTransportProvider = Provider<BackendTransport>((ref) {
  final transport = BackendTransport();
  ref.onDispose(transport.close);
  return transport;
});
final installationSessionProvider = Provider<InstallationSession>((ref) {
  return InstallationSession(
    origin: ref.watch(discogsConfigProvider).origin,
    store: ref.watch(backendStoreProvider),
    transport: ref.watch(backendTransportProvider),
  );
});
final discogsApiClientProvider = Provider<DiscogsApiClient>(
  (ref) => DiscogsApiClient(
    ref.watch(installationSessionProvider),
    ref.watch(backendTransportProvider),
  ),
);
final discogsAuthServiceProvider = Provider<DiscogsAuthService>(
  (ref) => DiscogsAuthService(
    apiClient: ref.watch(discogsApiClientProvider),
    store: ref.watch(backendStoreProvider),
  ),
);
final discogsCatalogServiceProvider = Provider<DiscogsCatalogService>(
  (ref) => DefaultDiscogsCatalogService(ref.watch(discogsApiClientProvider)),
);

final discogsAccountProvider = FutureProvider.autoDispose<DiscogsAccount?>((
  ref,
) {
  return ref.watch(discogsAuthServiceProvider).currentAccount();
});

final discogsAppLinksProvider = Provider<AppLinks>((ref) => AppLinks());

/// The AppLinks singleton is created during main() bootstrap, before database
/// initialization, so the OAuth callback is retained for both cold-start and
/// warm-app launches.
final incomingAppLinkStreamProvider = Provider<Stream<Uri>>((ref) {
  return ref.watch(discogsAppLinksProvider).uriLinkStream;
});

/// Intent deliveries are events, even when consecutive URIs are equal.
/// Riverpod's default equality filtering would otherwise discard later taps of
/// the same NFC tag indefinitely. The NFC logging service owns the cooldown.
class IncomingUriEvents extends StreamNotifier<Uri> {
  @override
  Stream<Uri> build() => ref.watch(incomingAppLinkStreamProvider);

  @override
  bool updateShouldNotify(AsyncValue<Uri> previous, AsyncValue<Uri> next) =>
      true;
}

final discogsIncomingUriProvider =
    StreamNotifierProvider<IncomingUriEvents, Uri>(IncomingUriEvents.new);

/// Lets widget tests opt out of platform app-link registration without
/// changing production behavior. The shared stream carries both Discogs OAuth
/// callbacks and NFC album intents.
final appLinksEnabledProvider = Provider<bool>((ref) => true);

enum DiscogsAuthorizationStatus {
  idle,
  awaitingCallback,
  completing,
  disconnecting,
  failed,
}

/// UI state for browser authorization completed by the backend.
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

/// Opens the browser, validates return URIs, and refreshes account state.
/// NFC album URIs share the incoming app-link stream but are not OAuth
/// callbacks; the root widget routes them to a different handler.
class DiscogsAuthorizationController
    extends Notifier<DiscogsAuthorizationState> {
  int _operationId = 0;

  @override
  DiscogsAuthorizationState build() => const DiscogsAuthorizationState.idle();

  Future<void> connect() async {
    if (state.isBusy) {
      return;
    }

    final config = ref.read(discogsConfigProvider);
    if (!config.isConfigured) {
      state = const DiscogsAuthorizationState.failed(
        DiscogsAuthenticationFailure('Discogs is unavailable in this build.'),
      );
      return;
    }

    final operationId = ++_operationId;
    state = const DiscogsAuthorizationState.awaitingCallback();
    try {
      await ref.read(discogsAuthServiceProvider).launchAuthorization();
    } catch (error) {
      if (operationId == _operationId) {
        state = DiscogsAuthorizationState.failed(_typedFailure(error));
      }
    }
  }

  /// Returns true when [uri] belongs to Groovefolio's Discogs callback,
  /// regardless of whether the callback succeeds. This lets the root app route
  /// the user back to Settings where success or failure can be shown.
  Future<bool> handleCallback(Uri uri) async {
    final config = ref.read(discogsConfigProvider);
    if (!config.matchesCallback(uri)) {
      return false;
    }

    await checkAuthorization();
    return true;
  }

  Future<void> checkAuthorization() async {
    if (state.status == DiscogsAuthorizationStatus.completing ||
        state.status == DiscogsAuthorizationStatus.disconnecting) {
      return;
    }
    final operationId = ++_operationId;
    state = const DiscogsAuthorizationState.completing();
    try {
      final status = await ref
          .read(discogsAuthServiceProvider)
          .authorizationStatus();
      if (operationId != _operationId) {
        return;
      }
      ref.invalidate(discogsAccountProvider);
      state = switch (status) {
        'pending' => const DiscogsAuthorizationState.awaitingCallback(),
        'canceled' => const DiscogsAuthorizationState.failed(
          DiscogsAuthenticationFailure(
            'Discogs connection canceled. No account was connected.',
          ),
        ),
        _ => const DiscogsAuthorizationState.idle(),
      };
    } catch (error) {
      if (operationId == _operationId) {
        state = DiscogsAuthorizationState.failed(_typedFailure(error));
      }
    }
  }

  Future<void> cancelAuthorization() async {
    final operationId = ++_operationId;
    try {
      await ref.read(discogsAuthServiceProvider).cancelAuthorization();
      if (operationId != _operationId) {
        return;
      }
      ref.invalidate(discogsAccountProvider);
      state = const DiscogsAuthorizationState.idle();
    } catch (error) {
      if (operationId == _operationId) {
        state = DiscogsAuthorizationState.failed(_typedFailure(error));
      }
    }
  }

  Future<void> disconnect() async {
    if (state.status == DiscogsAuthorizationStatus.disconnecting) {
      return;
    }

    final operationId = ++_operationId;
    state = const DiscogsAuthorizationState.disconnecting();
    try {
      await ref.read(discogsAuthServiceProvider).disconnect();
      if (operationId != _operationId) {
        return;
      }
      ref.invalidate(discogsAccountProvider);
      state = const DiscogsAuthorizationState.idle();
    } catch (error) {
      if (operationId == _operationId) {
        state = DiscogsAuthorizationState.failed(_typedFailure(error));
      }
    }
  }

  void clearFailure() {
    _operationId++;
    state = const DiscogsAuthorizationState.idle();
  }

  DiscogsFailure _typedFailure(Object error) {
    if (error is DiscogsFailure) {
      return error;
    }
    return const DiscogsApiFailure(
      'The Discogs connection could not be updated. Try again.',
    );
  }
}

final discogsAuthorizationControllerProvider =
    NotifierProvider<DiscogsAuthorizationController, DiscogsAuthorizationState>(
      DiscogsAuthorizationController.new,
    );
