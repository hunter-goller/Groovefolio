import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/providers/track_providers.dart';

void main() {
  test('albumTracksProvider delegates to TrackRepository', () async {
    final fake = _FakeTrackRepository();
    final container = ProviderContainer(
      overrides: [trackRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final tracks = await container.read(albumTracksProvider('album-1').future);

    expect(fake.albumIds, ['album-1']);
    expect(tracks.single.title, 'Blue Train');
  });

  test('blank album id returns empty tracklist', () async {
    final fake = _FakeTrackRepository();
    final container = ProviderContainer(
      overrides: [trackRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(await container.read(albumTracksProvider('   ').future), isEmpty);
    expect(fake.albumIds, isEmpty);
  });
}

class _FakeTrackRepository implements ITrackRepository {
  final List<String> albumIds = [];

  @override
  Future<List<Track>> findByAlbum(String albumId) async {
    albumIds.add(albumId);
    return const [
      Track(
        id: 'track-1',
        albumId: 'album-1',
        title: 'Blue Train',
        position: 'A1',
        side: 'A',
        sequence: 0,
        durationSeconds: 642,
        createdAt: '2026-08-19T00:00:00.000Z',
      ),
    ];
  }

  @override
  Future<List<Track>> replaceAlbumTracks(
    String albumId,
    Iterable<TrackDraft> tracks,
  ) => throw UnimplementedError();
}
