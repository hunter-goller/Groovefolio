import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/types/side_played.dart';

part 'stats_service.g.dart';

/// Collection-wide listening summary used by the Stats screen.
class CollectionSummary {
  const CollectionSummary({
    required this.totalAlbums,
    required this.totalPlays,
    required this.averagePlaysPerWeek,
  });

  final int totalAlbums;
  final int totalPlays;
  final double averagePlaysPerWeek;
}

/// Album plus its aggregate play count for ranked lists.
class RankedAlbum {
  const RankedAlbum({required this.album, required this.playCount});

  final Album album;
  final int playCount;
}

/// One month in a calendar-year listening series.
class MonthlyPlays {
  const MonthlyPlays({
    required this.year,
    required this.month,
    required this.playCount,
  });

  final int year;
  final int month;
  final int playCount;
}

/// Play-derived statistics for one album.
class AlbumStats {
  const AlbumStats({
    required this.album,
    required this.totalPlays,
    required this.fullAlbumPlays,
    required this.sideAPlays,
    required this.sideBPlays,
    required this.firstPlayedAt,
    required this.lastPlayedAt,
  });

  final Album album;
  final int totalPlays;
  final int fullAlbumPlays;
  final int sideAPlays;
  final int sideBPlays;
  final DateTime? firstPlayedAt;
  final DateTime? lastPlayedAt;
}

/// Computes listening statistics from repository data.
///
/// This service owns aggregation/business rules while repositories remain
/// responsible only for persistence and raw queries. It intentionally does
/// not depend on Drift or any UI layer.
class StatsService {
  StatsService({
    required this._albumRepository,
    required this._playRepository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final IAlbumRepository _albumRepository;
  final IPlayRepository _playRepository;
  final DateTime Function() _now;

  /// Returns collection totals and the average number of plays per week.
  ///
  /// The average uses the time between the first logged play and [now], with
  /// a minimum one-week window so a brand-new collection does not report an
  /// exaggerated rate after only a few hours or days.
  Future<CollectionSummary> getCollectionSummary() async {
    final albums = await _albumRepository.findAll();
    final plays = await _playRepository.findAll();

    if (plays.isEmpty) {
      return CollectionSummary(
        totalAlbums: albums.length,
        totalPlays: 0,
        averagePlaysPerWeek: 0,
      );
    }

    final parsedPlays = plays.map(_parsedPlayedAt).toList()..sort();
    final firstPlay = parsedPlays.first;
    final now = _now();
    final elapsed = now.isAfter(firstPlay)
        ? now.difference(firstPlay)
        : Duration.zero;
    final elapsedWeeks =
        elapsed.inMilliseconds / Duration.millisecondsPerDay / 7;
    final activityWeeks = elapsedWeeks < 1 ? 1.0 : elapsedWeeks;

    return CollectionSummary(
      totalAlbums: albums.length,
      totalPlays: plays.length,
      averagePlaysPerWeek: plays.length / activityWeeks,
    );
  }

  /// Returns played albums ranked by descending play count.
  ///
  /// Ties are resolved alphabetically by title and then by ID so results stay
  /// stable across runs and database implementations.
  Future<List<RankedAlbum>> getMostPlayedAlbums(int limit) async {
    if (limit <= 0) return const [];

    final albums = await _albumRepository.findAll();
    final plays = await _playRepository.findAll();
    final counts = <String, int>{};
    for (final play in plays) {
      counts.update(play.albumId, (count) => count + 1, ifAbsent: () => 1);
    }

    final ranked =
        [
          for (final album in albums)
            if ((counts[album.id] ?? 0) > 0)
              RankedAlbum(album: album, playCount: counts[album.id]!),
        ]..sort((left, right) {
          final byCount = right.playCount.compareTo(left.playCount);
          if (byCount != 0) return byCount;

          final byTitle = left.album.title.toLowerCase().compareTo(
            right.album.title.toLowerCase(),
          );
          if (byTitle != 0) return byTitle;
          return left.album.id.compareTo(right.album.id);
        });

    return List.unmodifiable(ranked.take(limit));
  }

  /// Returns all twelve months for [year], including months with zero plays.
  Future<List<MonthlyPlays>> getPlaysByMonth(int year) async {
    final plays = await _playRepository.findAll();
    final counts = List<int>.filled(12, 0);

    for (final play in plays) {
      final playedAt = _parsedPlayedAt(play).toLocal();
      if (playedAt.year == year) {
        counts[playedAt.month - 1] += 1;
      }
    }

    return List.unmodifiable([
      for (var month = 1; month <= 12; month += 1)
        MonthlyPlays(year: year, month: month, playCount: counts[month - 1]),
    ]);
  }

  /// Returns play-derived stats for [albumId], or null when the album is gone.
  Future<AlbumStats?> getAlbumStats(String albumId) async {
    final normalizedAlbumId = albumId.trim();
    if (normalizedAlbumId.isEmpty) {
      throw ArgumentError.value(
        albumId,
        'albumId',
        'Album ID cannot be empty.',
      );
    }

    final album = await _albumRepository.findById(normalizedAlbumId);
    if (album == null) return null;

    final plays = await _playRepository.findByAlbum(normalizedAlbumId);
    if (plays.isEmpty) {
      return AlbumStats(
        album: album,
        totalPlays: 0,
        fullAlbumPlays: 0,
        sideAPlays: 0,
        sideBPlays: 0,
        firstPlayedAt: null,
        lastPlayedAt: null,
      );
    }

    var fullAlbumPlays = 0;
    var sideAPlays = 0;
    var sideBPlays = 0;
    final playedAt = <DateTime>[];

    for (final play in plays) {
      playedAt.add(_parsedPlayedAt(play));
      switch (play.sidePlayed) {
        case SidePlayed.full:
          fullAlbumPlays += 1;
        case SidePlayed.sideA:
          sideAPlays += 1;
        case SidePlayed.sideB:
          sideBPlays += 1;
      }
    }
    playedAt.sort();

    return AlbumStats(
      album: album,
      totalPlays: plays.length,
      fullAlbumPlays: fullAlbumPlays,
      sideAPlays: sideAPlays,
      sideBPlays: sideBPlays,
      firstPlayedAt: playedAt.first,
      lastPlayedAt: playedAt.last,
    );
  }

  DateTime _parsedPlayedAt(Play play) => DateTime.parse(play.playedAt);
}

/// Injectable StatsService used by feature-level stats providers/screens.
@riverpod
StatsService statsService(Ref ref) {
  return StatsService(
    albumRepository: ref.watch(albumRepositoryProvider),
    playRepository: ref.watch(playRepositoryProvider),
  );
}
