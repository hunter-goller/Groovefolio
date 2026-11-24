import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/types/side_played.dart';

part 'stats_service.g.dart';

/// Collection-wide listening summary used by the Stats screen.
class CollectionSummary {
  const CollectionSummary({
    required this.totalAlbums,
    required this.playedAlbums,
    required this.totalPlays,
    required this.averagePlaysPerWeek,
  });

  final int totalAlbums;
  final int playedAlbums;
  final int totalPlays;
  final double averagePlaysPerWeek;
}

/// Album plus its aggregate play count for ranked lists.
class RankedAlbum {
  const RankedAlbum({required this.album, required this.playCount});

  final Album album;
  final int playCount;
}

/// Artist identifier plus aggregate listening totals for ranked lists.
class RankedArtist {
  const RankedArtist({
    required this.artistId,
    required this.playCount,
    required this.albumCount,
  });

  final String artistId;
  final int playCount;
  final int albumCount;
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
/// Stored play timestamps must be valid ISO-8601 text: aggregation parses them
/// strictly and surfaces corrupt values instead of silently changing totals.
/// Calendar grouping converts UTC storage timestamps to the device's local
/// time, which matters for plays close to midnight or a year boundary.
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

  /// Reads albums, plays and genre assignments once so a whole dashboard can
  /// be computed from the same data. The Stats screen uses this instead of
  /// the single-figure methods below, which each read the tables again.
  Future<StatsSnapshot> loadSnapshot() async {
    final albums = _albumRepository.findAll();
    final plays = _playRepository.findAll();
    final genres = _genreRepository.findAllByAlbum();
    return StatsSnapshot(
      albums: await albums,
      plays: await plays,
      genresByAlbum: await genres,
      now: _now(),
    );
  }

  Future<StatsSnapshot> _albumsAndPlays() async {
    final albums = _albumRepository.findAll();
    final plays = _playRepository.findAll();
    return StatsSnapshot(
      albums: await albums,
      plays: await plays,
      genresByAlbum: const {},
      now: _now(),
    );
  }

  /// See [StatsSnapshot.collectionSummary].
  Future<CollectionSummary> getCollectionSummary({int? year}) async =>
      (await _albumsAndPlays()).collectionSummary(year: year);

  /// See [StatsSnapshot.mostPlayedAlbums].
  Future<List<RankedAlbum>> getMostPlayedAlbums(int limit, {int? year}) async {
    if (limit <= 0) return const [];
    return (await _albumsAndPlays()).mostPlayedAlbums(limit, year: year);
  }

  /// See [StatsSnapshot.mostPlayedArtists].
  Future<List<RankedArtist>> getMostPlayedArtists({int? year}) async =>
      (await _albumsAndPlays()).mostPlayedArtists(year: year);

  /// See [StatsSnapshot.playsByMonth].
  Future<List<MonthlyPlays>> getPlaysByMonth(int year) async => StatsSnapshot(
    albums: const [],
    plays: await _playRepository.findAll(),
    genresByAlbum: const {},
    now: _now(),
  ).playsByMonth(year);

  /// See [StatsSnapshot.playsByYear].
  Future<List<YearlyPlays>> getPlaysByYear() async => StatsSnapshot(
    albums: const [],
    plays: await _playRepository.findAll(),
    genresByAlbum: const {},
    now: _now(),
  ).playsByYear();

  /// See [StatsSnapshot.genreBreakdown].
  Future<List<GenreStat>> getGenreBreakdown({int? year}) async {
    final plays = _playRepository.findAll();
    final genres = _genreRepository.findAllByAlbum();
    return StatsSnapshot(
      albums: const [],
      plays: await plays,
      genresByAlbum: await genres,
      now: _now(),
    ).genreBreakdown(year: year);
  }

  /// See [StatsSnapshot.firstVinyl].
  Future<Album?> getFirstVinyl() async => StatsSnapshot(
    albums: await _albumRepository.findAll(),
    plays: const [],
    genresByAlbum: const {},
    now: _now(),
  ).firstVinyl();

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
      playedAt.add(DateTime.parse(play.playedAt));
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
}

/// Facts behind the Stats "Insights" card. Each is a plain number; the screen
/// turns them into sentences, and a null or zero value hides that insight.
class StatsInsights {
  const StatsInsights({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.periodPlays,
    required this.previousPeriodPlays,
    required this.busiestWeekday,
    required this.busiestWeekdayPlays,
    required this.neverPlayedAlbums,
    required this.sideAPlays,
    required this.sideBPlays,
  });

  /// Consecutive local days with a play, ending today or yesterday.
  final int currentStreakDays;
  final int longestStreakDays;

  /// Plays in the comparison window: this year to date for a year range, or
  /// the last 365 days for all time.
  final int periodPlays;

  /// Plays in the same window one year earlier.
  final int previousPeriodPlays;

  /// [DateTime.monday] to [DateTime.sunday], or null with too few plays.
  final int? busiestWeekday;
  final int busiestWeekdayPlays;

  /// Records in the collection with no plays ever.
  final int neverPlayedAlbums;
  final int sideAPlays;
  final int sideBPlays;
}

/// Collection data read once, with every dashboard figure computed from it.
///
/// Play timestamps are parsed once, on first use, and shared by every figure.
/// Stored play timestamps must be valid ISO-8601 text: parsing is strict and
/// surfaces corrupt values instead of silently changing totals. Calendar
/// grouping converts UTC storage timestamps to the device's local time.
class StatsSnapshot {
  StatsSnapshot({
    required this.albums,
    required this.plays,
    required this.genresByAlbum,
    required this.now,
  });

  final List<Album> albums;
  final List<Play> plays;

  /// Genres per album ID, as returned by [IGenreRepository.findAllByAlbum].
  final Map<String, List<Genre>> genresByAlbum;
  final DateTime now;

  late final List<_DatedPlay> _dated = [
    for (final play in plays) _DatedPlay(play, DateTime.parse(play.playedAt)),
  ];

  List<_DatedPlay> _inYear(int? year) => year == null
      ? _dated
      : [
          for (final dated in _dated)
            if (dated.local.year == year) dated,
        ];

  /// Collection totals and the average number of plays per week.
  ///
  /// The average uses the time between the first included play and [now],
  /// with a minimum one-week window so a brand-new collection does not report
  /// an exaggerated rate after only a few hours or days.
  /// A year filter narrows plays, not totalAlbums; its average still runs to
  /// [now] rather than using a fixed 52-week denominator.
  CollectionSummary collectionSummary({int? year}) {
    final included = _inYear(year);

    if (included.isEmpty) {
      return CollectionSummary(
        totalAlbums: albums.length,
        playedAlbums: 0,
        totalPlays: 0,
        averagePlaysPerWeek: 0,
      );
    }

    final albumIds = albums.map((album) => album.id).toSet();
    final playedAlbums = included
        .map((dated) => dated.play.albumId)
        .where(albumIds.contains)
        .toSet()
        .length;

    var firstPlay = included.first.at;
    for (final dated in included) {
      if (dated.at.isBefore(firstPlay)) firstPlay = dated.at;
    }
    final elapsed = now.isAfter(firstPlay)
        ? now.difference(firstPlay)
        : Duration.zero;
    final elapsedWeeks =
        elapsed.inMilliseconds / Duration.millisecondsPerDay / 7;
    final activityWeeks = elapsedWeeks < 1 ? 1.0 : elapsedWeeks;

    return CollectionSummary(
      totalAlbums: albums.length,
      playedAlbums: playedAlbums,
      totalPlays: included.length,
      averagePlaysPerWeek: included.length / activityWeeks,
    );
  }

  /// Played albums ranked by descending play count.
  ///
  /// Ties are resolved alphabetically by title and then by ID so results stay
  /// stable across runs and database implementations.
  List<RankedAlbum> mostPlayedAlbums(int limit, {int? year}) {
    if (limit <= 0) return const [];

    final counts = <String, int>{};
    for (final dated in _inYear(year)) {
      counts.update(
        dated.play.albumId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
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

  /// Artists ranked by plays across every record by that artist.
  ///
  /// The screen resolves artist names and uses them to break equal-play ties.
  /// Returning every played artist lets that final ordering happen before the
  /// visible list is limited.
  List<RankedArtist> mostPlayedArtists({int? year}) {
    final included = _inYear(year);
    if (included.isEmpty) return const [];

    final artistByAlbum = {
      for (final album in albums) album.id: album.artistId,
    };
    final playCounts = <String, int>{};
    final albumsByArtist = <String, Set<String>>{};

    for (final dated in included) {
      final artistId = artistByAlbum[dated.play.albumId];
      if (artistId == null) continue;
      playCounts.update(artistId, (count) => count + 1, ifAbsent: () => 1);
      albumsByArtist
          .putIfAbsent(artistId, () => <String>{})
          .add(dated.play.albumId);
    }

    final ranked =
        [
          for (final entry in playCounts.entries)
            RankedArtist(
              artistId: entry.key,
              playCount: entry.value,
              albumCount: albumsByArtist[entry.key]!.length,
            ),
        ]..sort((left, right) {
          final byPlays = right.playCount.compareTo(left.playCount);
          if (byPlays != 0) return byPlays;
          return left.artistId.compareTo(right.artistId);
        });

    return List.unmodifiable(ranked);
  }

  /// All twelve months for [year], including months with zero plays.
  List<MonthlyPlays> playsByMonth(int year) {
    final counts = List<int>.filled(12, 0);
    for (final dated in _dated) {
      if (dated.local.year == year) {
        counts[dated.local.month - 1] += 1;
      }
    }

    return List.unmodifiable([
      for (var month = 1; month <= 12; month += 1)
        MonthlyPlays(year: year, month: month, playCount: counts[month - 1]),
    ]);
  }

  /// Every calendar year represented by play history, oldest first.
  ///
  /// Unlike [playsByMonth], this does not synthesize empty years between the
  /// first and last play. The all-time chart represents actual years in which
  /// listening activity exists.
  List<YearlyPlays> playsByYear() {
    if (_dated.isEmpty) return const [];

    final counts = <int, int>{};
    for (final dated in _dated) {
      counts.update(dated.local.year, (count) => count + 1, ifAbsent: () => 1);
    }

    final years = counts.keys.toList()..sort();
    return List.unmodifiable([
      for (final year in years)
        YearlyPlays(year: year, playCount: counts[year]!),
    ]);
  }

  /// Play-weighted genre shares for the collection.
  ///
  /// Each play contributes once to every genre assigned to its album. For
  /// example, one play of an album tagged Jazz + Hard Bop contributes one
  /// count to Jazz and one count to Hard Bop. Plays for albums without genre
  /// assignments are intentionally excluded.
  ///
  /// Results are ordered by descending attributed play count, then
  /// case-insensitive genre name, then genre ID for deterministic ties.
  List<GenreStat> genreBreakdown({int? year}) {
    final included = _inYear(year);
    if (included.isEmpty) return const [];

    final playCountsByAlbum = <String, int>{};
    for (final dated in included) {
      playCountsByAlbum.update(
        dated.play.albumId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final genreCounts = <String, _GenreCount>{};
    for (final entry in playCountsByAlbum.entries) {
      for (final genre in genresByAlbum[entry.key] ?? const <Genre>[]) {
        final existing = genreCounts[genre.id];
        genreCounts[genre.id] = _GenreCount(
          genre: genre,
          playCount: (existing?.playCount ?? 0) + entry.value,
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

  /// Streak, year-over-year, busiest day, never-played and side facts.
  ///
  /// Streaks and never-played always use all history; the busiest day and
  /// side balance follow the [year] filter. A busiest day needs at least
  /// [minPlaysForHabits] plays in range so one session can't define a habit.
  StatsInsights insights({int? year, int minPlaysForHabits = 5}) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);

    final days = <DateTime>{
      for (final dated in _dated)
        DateTime(dated.local.year, dated.local.month, dated.local.day),
    };
    var longest = 0;
    for (final day in days) {
      if (days.contains(_previousDay(day))) continue;
      var length = 1;
      var next = _nextDay(day);
      while (days.contains(next)) {
        length++;
        next = _nextDay(next);
      }
      if (length > longest) longest = length;
    }
    var current = 0;
    var cursor = days.contains(today) ? today : _previousDay(today);
    while (days.contains(cursor)) {
      current++;
      cursor = _previousDay(cursor);
    }

    final DateTime periodStart;
    final DateTime previousStart;
    final DateTime previousEnd;
    if (year == null) {
      periodStart = today.subtract(const Duration(days: 364));
      previousStart = DateTime(
        periodStart.year - 1,
        periodStart.month,
        periodStart.day,
      );
      previousEnd = DateTime(today.year - 1, today.month, today.day);
    } else {
      periodStart = DateTime(year);
      previousStart = DateTime(year - 1);
      previousEnd = DateTime(year - 1, localNow.month, localNow.day);
    }
    var periodPlays = 0;
    var previousPlays = 0;
    for (final dated in _dated) {
      final day = DateTime(
        dated.local.year,
        dated.local.month,
        dated.local.day,
      );
      if (!day.isBefore(periodStart) && !day.isAfter(today)) periodPlays++;
      if (!day.isBefore(previousStart) && !day.isAfter(previousEnd)) {
        previousPlays++;
      }
    }

    final included = _inYear(year);
    final byWeekday = List<int>.filled(8, 0);
    var sideA = 0;
    var sideB = 0;
    for (final dated in included) {
      byWeekday[dated.local.weekday]++;
      switch (dated.play.sidePlayed) {
        case SidePlayed.sideA:
          sideA++;
        case SidePlayed.sideB:
          sideB++;
        case SidePlayed.full:
          break;
      }
    }
    int? busiest;
    if (included.length >= minPlaysForHabits) {
      for (
        var weekday = DateTime.monday;
        weekday <= DateTime.sunday;
        weekday++
      ) {
        if (busiest == null || byWeekday[weekday] > byWeekday[busiest]) {
          busiest = weekday;
        }
      }
    }

    final playedIds = {for (final dated in _dated) dated.play.albumId};
    return StatsInsights(
      currentStreakDays: current,
      longestStreakDays: longest,
      periodPlays: periodPlays,
      previousPeriodPlays: previousPlays,
      busiestWeekday: busiest,
      busiestWeekdayPlays: busiest == null ? 0 : byWeekday[busiest],
      neverPlayedAlbums: albums
          .where((album) => !playedIds.contains(album.id))
          .length,
      sideAPlays: sideA,
      sideBPlays: sideB,
    );
  }

  // Calendar arithmetic, so a daylight-saving change can't skip or repeat a day.
  static DateTime _previousDay(DateTime day) =>
      DateTime(day.year, day.month, day.day - 1);
  static DateTime _nextDay(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1);

  /// The first vinyl added to the app collection.
  ///
  /// This is derived from the earliest Album.createdAt rather than stored
  /// separately, so it remains correct if collection data changes.
  Album? firstVinyl() {
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
}

class _DatedPlay {
  _DatedPlay(this.play, this.at);

  final Play play;
  final DateTime at;
  late final DateTime local = at.toLocal();
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
