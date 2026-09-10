import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/services/notifications/nfc_play_notification_service.dart';
import 'package:vinyl_app/types/side_played.dart';

void main() {
  const album = Album(
    id: 'album-1',
    title: 'Blue Train',
    artistId: 'artist-1',
    artworkPath: '/data/user/0/app/app_flutter/artwork/album-1.jpg',
    createdAt: '2026-09-08T00:00:00.000Z',
  );
  const play = Play(
    id: 'play-1',
    albumId: 'album-1',
    playedAt: '2026-09-08T12:00:00.000Z',
    sidePlayed: SidePlayed.full,
    createdAt: '2026-09-08T12:00:00.000Z',
  );

  test(
    'automatic NFC play sends the bounded Android notification payload',
    () async {
      String? method;
      Map<String, Object?>? arguments;
      final service = AndroidNfcPlayNotificationService(
        isAndroid: true,
        invoke: (invokedMethod, invokedArguments) async {
          method = invokedMethod;
          arguments = invokedArguments;
          return true;
        },
      );

      final shown = await service.showLoggedPlay(album: album, play: play);

      expect(shown, isTrue);
      expect(method, 'showNfcPlayLogged');
      expect(arguments, {
        'playId': 'play-1',
        'albumId': 'album-1',
        'albumTitle': 'Blue Train',
        'sideLabel': 'Full album',
        'artworkPath': '/data/user/0/app/app_flutter/artwork/album-1.jpg',
      });
    },
  );

  test('notification links are navigation-only and strictly validated', () {
    expect(
      albumIdFromNotificationUri(
        Uri.parse('groovefolio-notification://album/album-1/play-1'),
      ),
      'album-1',
    );
    for (final value in [
      'groovefolio://album/album-1',
      'groovefolio-notification://album/album-1/play-1/extra',
      'groovefolio-notification://album/album-1/play-1?undo=play-1',
      'groovefolio-notification://album/album-1/play-1#fragment',
      'groovefolio-notification://user@album/album-1/play-1',
      'groovefolio-notification://album/a%2Fb/play-1',
      'groovefolio-notification://album/album-1/a%2Fb',
    ]) {
      expect(
        albumIdFromNotificationUri(Uri.parse(value)),
        isNull,
        reason: value,
      );
    }
  });

  test(
    'missing artwork is omitted and denied permission returns false',
    () async {
      final service = AndroidNfcPlayNotificationService(
        isAndroid: true,
        invoke: (method, arguments) async {
          expect(arguments.containsKey('artworkPath'), isFalse);
          return false;
        },
      );
      const noArtwork = Album(
        id: 'album-1',
        title: 'Blue Train',
        artistId: 'artist-1',
        createdAt: '2026-09-08',
      );
      expect(
        await service.showLoggedPlay(album: noArtwork, play: play),
        isFalse,
      );
    },
  );

  test('unsupported platform does not invoke the Android channel', () async {
    var calls = 0;
    final service = AndroidNfcPlayNotificationService(
      isAndroid: false,
      invoke: (method, arguments) async {
        calls += 1;
        return true;
      },
    );

    expect(await service.showLoggedPlay(album: album, play: play), isFalse);
    expect(calls, 0);
  });

  test('platform failure returns false for in-app fallback', () async {
    final service = AndroidNfcPlayNotificationService(
      isAndroid: true,
      invoke: (method, arguments) {
        throw PlatformException(code: 'notifications_disabled');
      },
    );

    expect(await service.showLoggedPlay(album: album, play: play), isFalse);
  });
}
