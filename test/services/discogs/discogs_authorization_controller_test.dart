import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/services/discogs/discogs_auth_service.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';

void main() {
  late FakeAuth auth;
  late ProviderContainer container;
  setUp(() {
    auth = FakeAuth();
    container = ProviderContainer(
      overrides: [discogsAuthServiceProvider.overrideWithValue(auth)],
    );
  });
  tearDown(() => container.dispose());
  test(
    'connect waits; check queries server transaction and completes',
    () async {
      final controller = container.read(
        discogsAuthorizationControllerProvider.notifier,
      );
      await controller.connect();
      expect(auth.launched, isTrue);
      expect(
        container
            .read(discogsAuthorizationControllerProvider)
            .isAwaitingCallback,
        isTrue,
      );
      await controller.checkAuthorization();
      expect(
        container
            .read(discogsAuthorizationControllerProvider)
            .isAwaitingCallback,
        isTrue,
      );
      auth.status = 'connected';
      await controller.checkAuthorization();
      expect(
        container.read(discogsAuthorizationControllerProvider).status,
        DiscogsAuthorizationStatus.idle,
      );
    },
  );
  test(
    'simultaneous resume and bare app-return link share verification',
    () async {
      final result = Completer<String>();
      auth.pendingCheck = result.future;
      final controller = container.read(
        discogsAuthorizationControllerProvider.notifier,
      );
      final resumed = controller.checkAuthorization();
      expect(
        await controller.handleCallback(
          Uri.parse('groovefolio://discogs-auth'),
        ),
        isTrue,
      );
      expect(auth.checks, 1);
      result.complete('connected');
      await resumed;
      expect(
        container.read(discogsAuthorizationControllerProvider).status,
        DiscogsAuthorizationStatus.idle,
      );
    },
  );

  test('deep link parameters cannot complete authorization themselves', () async {
    final controller = container.read(
      discogsAuthorizationControllerProvider.notifier,
    );
    expect(
      await controller.handleCallback(
        Uri.parse(
          'groovefolio://discogs-auth?oauth_token=forged&oauth_verifier=forged',
        ),
      ),
      isTrue,
    );
    expect(auth.checks, 1);
    expect(
      container.read(discogsAuthorizationControllerProvider).isAwaitingCallback,
      isTrue,
    );
    expect(
      await controller.handleCallback(Uri.parse('groovefolio://album/123')),
      isFalse,
    );
    expect(auth.checks, 1);
  });
  test(
    'cold-start check recovers pending state and cancellation refreshes account',
    () async {
      final controller = container.read(
        discogsAuthorizationControllerProvider.notifier,
      );
      await controller.checkAuthorization();
      expect(
        container
            .read(discogsAuthorizationControllerProvider)
            .isAwaitingCallback,
        isTrue,
      );
      await controller.cancelAuthorization();
      expect(auth.canceled, isTrue);
      expect(
        container.read(discogsAuthorizationControllerProvider).status,
        DiscogsAuthorizationStatus.idle,
      );
    },
  );
  test(
    'failed server verification shows failure without claiming connection',
    () async {
      auth.failure = const DiscogsNetworkFailure('Offline');
      final controller = container.read(
        discogsAuthorizationControllerProvider.notifier,
      );
      await controller.checkAuthorization();
      expect(
        container.read(discogsAuthorizationControllerProvider).status,
        DiscogsAuthorizationStatus.failed,
      );
    },
  );
}

class FakeAuth implements DiscogsAuthService {
  bool launched = false, canceled = false;
  int checks = 0;
  String status = 'pending';
  DiscogsFailure? failure;
  Future<String>? pendingCheck;
  @override
  Future<DiscogsAccount?> currentAccount() async => null;
  @override
  Future<Uri> beginAuthorization() async =>
      Uri.parse('https://www.discogs.com/oauth/authorize');
  @override
  Future<void> launchAuthorization() async {
    launched = true;
  }

  @override
  Future<String> authorizationStatus() async {
    checks++;
    if (failure != null) {
      throw failure!;
    }
    return pendingCheck ?? Future.value(status);
  }

  @override
  Future<void> cancelAuthorization() async {
    canceled = true;
  }

  @override
  Future<void> disconnect() async {}
}
