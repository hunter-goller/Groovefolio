import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/db/database_provider.dart';
import 'package:vinyl_app/main.dart';
import 'package:vinyl_app/repositories/play_repository.dart';
import 'package:vinyl_app/services/discogs/discogs_providers.dart';
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

void main() {
  for (final allowed in [true, false]) {
    testWidgets(
      'NFC feedback and exact-play Undo, notifications allowed=$allowed',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final uris = StreamController<Uri>();
        final notifications = _Notifications(allowed);
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
        final older = await repository.create(
          albumId: 'album-1',
          playedAt: DateTime.utc(2026),
          sidePlayed: SidePlayed.full,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              incomingAppLinkStreamProvider.overrideWithValue(uris.stream),
              onboardingRequiredProvider.overrideWithValue(
                const AsyncData(false),
              ),
              nfcAvailabilityProvider.overrideWith(
                (ref) async => NfcAvailabilityState.unsupported,
              ),
              nfcPlayNotificationServiceProvider.overrideWithValue(
                notifications,
              ),
            ],
            child: const MyApp(),
          ),
        );
        await tester.pumpAndSettle();
        uris.add(Uri.parse('groovefolio://album/album-1'));
        await tester.pumpAndSettle();
        expect(notifications.plays, hasLength(1));
        expect(haptics, 1);
        expect(await repository.findAll(), hasLength(2));
        expect(find.text('Undo'), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect((await repository.findAll()).map((p) => p.id), [older.id]);
        // Database completion and native-notification cleanup may schedule
        // feedback after the first animation settlement.
        await tester.pumpAndSettle();
        expect(find.text('Play removed.'), findsOneWidget);
        // An immediate callback is still suppressed after Undo.
        uris.add(Uri.parse('groovefolio://album/album-1'));
        await tester.pumpAndSettle();
        expect(notifications.plays, hasLength(1));
        expect(haptics, 1);
        expect(await repository.findAll(), hasLength(1));
        // Notification navigation is not another NFC log event.
        uris.add(Uri.parse('groovefolio-notification://album/album-1/play-1'));
        await tester.pumpAndSettle();
        expect(find.text('Album Details'), findsOneWidget);
        expect(await repository.findAll(), hasLength(1));
        expect(notifications.plays, hasLength(1));
        uris.add(
          Uri.parse('groovefolio-notification://album/missing-album/play-2'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('That record is no longer in your collection.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
