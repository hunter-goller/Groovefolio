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

/// One calendar year in an all-time listening series.
class YearlyPlays {
  const YearlyPlays({required this.year, required this.playCount});

  final int year;
  final int playCount;
}

/// Play-weighted listening share for one genre.
class GenreStat {
  const GenreStat({
    required this.genre,
    required this.playCount,
    required this.share,
  });

  final Genre genre;
  final int playCount;

  /// Fraction of all genre-attributed plays represented by this genre.
  ///
  /// This is normalized to the 0.0-1.0 range so UI progress indicators can
  /// consume it directly.
  final double share;

  /// Percentage form of [share], in the 0-100 range.
  double get percentage => share * 100;
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
    required this._genreRepository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final IAlbumRepository _albumRepository;
  final IPlayRepository _playRepository;
  final IGenreRepository _genreRepository;
  final DateTime Function() _now;

  /// Returns collection totals and the average number of plays per week.
  ///
  /// The average uses the time between the first logged play and [now], with
  /// a minimum one-week window so a brand-new collection does not report an
  /// exaggerated rate after only a few hours or days.
  Future<CollectionSummary> getCollectionSummary({int? year}) async {
    final albums = await _albumRepository.findAll();
    final plays = _filterPlaysByYear(await _playRepository.findAll(), year);

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
  Future<List<RankedAlbum>> getMostPlayedAlbums(int limit, {int? year}) async {
    if (limit <= 0) return const [];

    final albums = await _albumRepository.findAll();
    final plays = _filterPlaysByYear(await _playRepository.findAll(), year);
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

  /// Returns every calendar year represented by play history, oldest first.
  ///
  /// Unlike [getPlaysByMonth], this does not synthesize empty years between
  /// the first and last play. The all-time chart represents actual years in
  /// which listening activity exists.
  Future<List<YearlyPlays>> getPlaysByYear() async {
    final plays = await _playRepository.findAll();
    if (plays.isEmpty) return const [];

    final counts = <int, int>{};
    for (final play in plays) {
      final year = _parsedPlayedAt(play).toLocal().year;
      counts.update(year, (count) => count + 1, ifAbsent: () => 1);
    }

    final years = counts.keys.toList()..sort();
    return List.unmodifiable([
      for (final year in years)
        YearlyPlays(year: year, playCount: counts[year]!),
    ]);
  }

  /// Returns play-weighted genre shares for the collection.
  ///
  /// Each play contributes once to every genre assigned to its album. For
  /// example, one play of an album tagged Jazz + Hard Bop contributes one
  /// count to Jazz and one count to Hard Bop. Plays for albums without genre
  /// assignments are intentionally excluded.
  ///
  /// Results are ordered by descending attributed play count, then
  /// case-insensitive genre name, then genre ID for deterministic ties.
  Future<List<GenreStat>> getGenreBreakdown({int? year}) async {
    final plays = _filterPlaysByYear(await _playRepository.findAll(), year);
    if (plays.isEmpty) return const [];

    final playCountsByAlbum = <String, int>{};
    for (final play in plays) {
      playCountsByAlbum.update(
        play.albumId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final genreCounts = <String, _GenreCount>{};
    final assignments = await Future.wait([
      for (final entry in playCountsByAlbum.entries)
        _genresForAlbum(entry.key, entry.value),
    ]);

    for (final assignment in assignments) {
      for (final genre in assignment.genres) {
        final existing = genreCounts[genre.id];
        genreCounts[genre.id] = _GenreCount(
          genre: genre,
          playCount: (existing?.playCount ?? 0) + assignment.playCount,
        );
      }
    }

    if (genreCounts.isEmpty) return const [];

    final totalAttributedPlays = genreCounts.values.fold<int>(
      0,
      (total, stat) => total + stat.playCount,
    );
    final stats =
        [
          for (final count in genreCounts.values)
            GenreStat(
              genre: count.genre,
              playCount: count.playCount,
              share: count.playCount / totalAttributedPlays,
            ),
        ]..sort((left, right) {
          final byCount = right.playCount.compareTo(left.playCount);
          if (byCount != 0) return byCount;

          final byName = left.genre.name.toLowerCase().compareTo(
            right.genre.name.toLowerCase(),
          );
          if (byName != 0) return byName;
          return left.genre.id.compareTo(right.genre.id);
        });

    return List.unmodifiable(stats);
  }

  Future<_AlbumGenreAssignment> _genresForAlbum(
    String albumId,
    int playCount,
  ) async {
    return _AlbumGenreAssignment(
      genres: await _genreRepository.findByAlbum(albumId),
      playCount: playCount,
    );
  }

  /// Returns the first vinyl added to the app collection.
  ///
  /// This is derived from the earliest Album.createdAt rather than stored
  /// separately, so it remains correct if collection data changes.
  Future<Album?> getFirstVinyl() async {
    final albums = await _albumRepository.findAll();
    if (albums.isEmpty) return null;

    final ordered = List<Album>.of(albums)
      ..sort((left, right) {
        final leftCreated = DateTime.tryParse(left.createdAt);
        final rightCreated = DateTime.tryParse(right.createdAt);

        if (leftCreated != null && rightCreated != null) {
          final byDate = leftCreated.compareTo(rightCreated);
          if (byDate != 0) return byDate;
        } else if (leftCreated != null) {
          return -1;
        } else if (rightCreated != null) {
          return 1;
        }

        final byTitle = left.title.toLowerCase().compareTo(
          right.title.toLowerCase(),
        );
        if (byTitle != 0) return byTitle;
        return left.id.compareTo(right.id);
      });

    return ordered.first;
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

  List<Play> _filterPlaysByYear(List<Play> plays, int? year) {
    if (year == null) return plays;
    return plays
        .where((play) => _parsedPlayedAt(play).toLocal().year == year)
        .toList(growable: false);
  }

  DateTime _parsedPlayedAt(Play play) => DateTime.parse(play.playedAt);
}

/// Injectable StatsService used by feature-level stats providers/screens.
@riverpod
StatsService statsService(Ref ref) {
  return StatsService(
    albumRepository: ref.watch(albumRepositoryProvider),
    playRepository: ref.watch(playRepositoryProvider),
    genreRepository: ref.watch(genreRepositoryProvider),
  );
}

class _GenreCount {
  const _GenreCount({required this.genre, required this.playCount});

  final Genre genre;
  final int playCount;
}

class _AlbumGenreAssignment {
  const _AlbumGenreAssignment({required this.genres, required this.playCount});

  final List<Genre> genres;
  final int playCount;
}
