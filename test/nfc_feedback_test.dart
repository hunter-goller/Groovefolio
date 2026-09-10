import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/main.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
import 'package:vinyl_app/services/nfc/nfc_delivery_context.dart';
import 'package:vinyl_app/services/nfc/nfc_platform_adapter.dart';
import 'package:vinyl_app/services/nfc/nfc_service.dart';
import 'package:vinyl_app/services/notifications/nfc_play_notification_service.dart';
import 'package:vinyl_app/services/onboarding_service.dart';
import 'package:vinyl_app/types/side_played.dart';

class _Notifications implements INfcPlayNotificationService {
  _Notifications(this.allowed);
  final bool allowed;
  final plays = <Play>[];
  @override
  Future<bool> showLoggedPlay({
    required Album album,
    required Play play,
  }) async {
    plays.add(play);
    return allowed;
  }
}

class _Deliveries implements INfcDeliveryContextService {
  _Deliveries(this.pending);

  final List<NfcDeliveryContext> pending;
  final completed = <NfcDeliveryContext>[];
  final messages = <String>[];

  @override
  Future<NfcDeliveryContext> consume() async {
    return pending.isEmpty
        ? const NfcDeliveryContext.foreground()
        : pending.removeAt(0);
  }

  @override
  Future<void> completeExternal(NfcDeliveryContext delivery) async {
    if (delivery.isExternal) completed.add(delivery);
  }

  @override
  Future<void> showExternalMessage(String message) async {
    messages.add(message);
  }
}

void main() {
  testWidgets('foreground NFC uses haptic and in-app exact-play Undo only', (
    tester,
  ) async {
    final fixture = await _pumpNfcApp(
      tester,
      deliveries: _Deliveries([
        const NfcDeliveryContext(id: 1, mode: NfcDeliveryMode.foreground),
        const NfcDeliveryContext(id: 2, mode: NfcDeliveryMode.foreground),
      ]),
      notificationsAllowed: true,
      withOlderPlay: true,
    );

    fixture.uris.add(Uri.parse('groovefolio://album/album-1'));
    await tester.pumpAndSettle();

    expect(fixture.notifications.plays, isEmpty);
    expect(fixture.haptics(), 1);
    expect(await fixture.repository.findAll(), hasLength(2));
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await fixture.repository.findAll()).map((p) => p.id), [
      fixture.olderPlay!.id,
    ]);
    expect(find.text('Play removed.'), findsOneWidget);

    // An immediate callback is still suppressed after Undo and stays silent.
    fixture.uris.add(Uri.parse('groovefolio://album/album-1'));
    await tester.pumpAndSettle();
    expect(fixture.notifications.plays, isEmpty);
    expect(fixture.haptics(), 1);
    expect(await fixture.repository.findAll(), hasLength(1));

    // Notification navigation remains navigation-only.
    fixture.uris.add(
      Uri.parse('groovefolio-notification://album/album-1/play-1'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Album Details'), findsOneWidget);
    expect(await fixture.repository.findAll(), hasLength(1));
  });

  for (final notificationsAllowed in [true, false]) {
    testWidgets(
      'external NFC uses one system confirmation, allowed=$notificationsAllowed',
      (tester) async {
        final deliveries = _Deliveries([
          const NfcDeliveryContext(id: 7, mode: NfcDeliveryMode.external),
        ]);
        final fixture = await _pumpNfcApp(
          tester,
          deliveries: deliveries,
          notificationsAllowed: notificationsAllowed,
        );

        fixture.uris.add(Uri.parse('groovefolio://album/album-1'));
        await tester.pumpAndSettle();

        expect(await fixture.repository.findAll(), hasLength(1));
        expect(fixture.notifications.plays, hasLength(1));
        expect(fixture.haptics(), 0);
        expect(find.text('Undo'), findsNothing);
        expect(deliveries.completed, hasLength(1));
        expect(
          deliveries.messages,
          notificationsAllowed ? isEmpty : ['Play logged: Test Album'],
        );
      },
    );
  }

  testWidgets('external invalid and missing albums complete without success', (
    tester,
  ) async {
    final deliveries = _Deliveries([
      const NfcDeliveryContext(id: 20, mode: NfcDeliveryMode.external),
      const NfcDeliveryContext(id: 21, mode: NfcDeliveryMode.external),
    ]);
    final fixture = await _pumpNfcApp(
      tester,
      deliveries: deliveries,
      notificationsAllowed: true,
    );

    fixture.uris.add(Uri.parse('groovefolio://album/bad?unexpected=true'));
    await tester.pumpAndSettle();
    fixture.uris.add(Uri.parse('groovefolio://album/missing-album'));
    await tester.pumpAndSettle();

    expect(await fixture.repository.findAll(), isEmpty);
    expect(fixture.notifications.plays, isEmpty);
    expect(fixture.haptics(), 0);
    expect(deliveries.completed, hasLength(2));
    expect(deliveries.messages, [
      'This NFC tag is linked to a record that is no longer in your '
          'collection. Add the record again and relink the tag.',
    ]);
  });
}

class _NfcAppFixture {
  const _NfcAppFixture({
    required this.uris,
    required this.notifications,
    required this.repository,
    required this.haptics,
    this.olderPlay,
  });

  final StreamController<Uri> uris;
  final _Notifications notifications;
  final PlayRepository repository;
  final int Function() haptics;
  final Play? olderPlay;
}

Future<_NfcAppFixture> _pumpNfcApp(
  WidgetTester tester, {
  required _Deliveries deliveries,
  required bool notificationsAllowed,
  bool withOlderPlay = false,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final uris = StreamController<Uri>();
  final notifications = _Notifications(notificationsAllowed);
  var haptics = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics++;
      return null;
    },
  );
  addTearDown(() async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await uris.close();
    await db.close();
  });
  await db
      .into(db.artists)
      .insert(
        ArtistsCompanion.insert(
          id: 'artist-1',
          name: 'Artist',
          createdAt: '2026-09-09',
        ),
      );
  await db
      .into(db.albums)
      .insert(
        AlbumsCompanion.insert(
          id: 'album-1',
          title: 'Test Album',
          artistId: 'artist-1',
          createdAt: '2026-09-09',
        ),
      );
  final repository = PlayRepository(db);
  final older = withOlderPlay
      ? await repository.create(
          albumId: 'album-1',
          playedAt: DateTime.utc(2026),
          sidePlayed: SidePlayed.full,
        )
      : null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        incomingAppLinkStreamProvider.overrideWithValue(uris.stream),
        onboardingRequiredProvider.overrideWithValue(const AsyncData(false)),
        nfcAvailabilityProvider.overrideWith(
          (ref) async => NfcAvailabilityState.unsupported,
        ),
        nfcPlayNotificationServiceProvider.overrideWithValue(notifications),
        nfcDeliveryContextServiceProvider.overrideWithValue(deliveries),
      ],
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _NfcAppFixture(
    uris: uris,
    notifications: notifications,
    repository: repository,
    haptics: () => haptics,
    olderPlay: older,
  );
}
