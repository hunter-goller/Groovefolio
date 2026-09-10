import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';

part 'recommendation_service.g.dart';

enum RecommendationKind { rediscover, genre, era, underplayed }

class TasteGenre {
  const TasteGenre({
    required this.genre,
    required this.playCount,
    required this.share,
  });

  final Genre genre;
  final int playCount;
  final double share;
}

class TasteProfile {
  const TasteProfile({
    required this.totalPlays,
    required this.playedAlbums,
    required this.topGenres,
    required this.favoriteDecade,
    this.favoriteDecadePlayCount = 0,
  });

  final int totalPlays;
  final int playedAlbums;
  final List<TasteGenre> topGenres;
  final int? favoriteDecade;
  final int favoriteDecadePlayCount;
}

class AlbumRecommendation {
  const AlbumRecommendation({
    required this.album,
    required this.artistName,
    required this.genres,
    required this.reason,
    required this.kind,
    required this.playCount,
    required this.score,
    this.lastPlayedAt,
  });

  final Album album;
  final String artistName;
  final List<String> genres;
  final String reason;
  final RecommendationKind kind;
  final int playCount;
  final int score;
  final DateTime? lastPlayedAt;
}

class DiscoverRecommendations {
  const DiscoverRecommendations({
    required this.collectionSize,
    required this.tasteProfile,
    required this.rediscover,
    required this.genrePicks,
    required this.eraPicks,
    this.underplayed = const [],
  });

  final int collectionSize;
  final TasteProfile? tasteProfile;
  final List<AlbumRecommendation> rediscover;
  final List<AlbumRecommendation> genrePicks;
  final List<AlbumRecommendation> eraPicks;
  final List<AlbumRecommendation> underplayed;

  bool get hasRecommendations =>
      rediscover.isNotEmpty ||
      genrePicks.isNotEmpty ||
      eraPicks.isNotEmpty ||
      underplayed.isNotEmpty;
}

abstract interface class IRecommendationService {
  Future<DiscoverRecommendations> getRecommendations({
    Duration rediscoverThreshold = const Duration(days: 90),
    Duration recentSuppression = const Duration(days: 30),
    int sectionLimit = 6,
  });
}

class RecommendationService implements IRecommendationService {
  RecommendationService({
    required this._albumRepository,
    required this._artistRepository,
    required this._playRepository,
    required this._genreRepository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final IAlbumRepository _albumRepository;
  final IArtistRepository _artistRepository;
  final IPlayRepository _playRepository;
  final IGenreRepository _genreRepository;
  final DateTime Function() _now;

  @override
  Future<DiscoverRecommendations> getRecommendations({
    Duration rediscoverThreshold = const Duration(days: 90),
    Duration recentSuppression = const Duration(days: 30),
    int sectionLimit = 6,
  }) async {
    if (sectionLimit <= 0) {
      throw ArgumentError.value(
        sectionLimit,
        'sectionLimit',
        'Section limit must be greater than zero.',
      );
    }

    final albumsFuture = _albumRepository.findAll();
    final artistsFuture = _artistRepository.findAll();
    final playsFuture = _playRepository.findAll();

    final albums = await albumsFuture;
    final artists = await artistsFuture;
    final plays = await playsFuture;

    if (albums.isEmpty) {
      return const DiscoverRecommendations(
        collectionSize: 0,
        tasteProfile: null,
        rediscover: [],
        genrePicks: [],
        eraPicks: [],
      );
    }

    final albumIds = albums.map((album) => album.id).toSet();
    final artistsById = {for (final artist in artists) artist.id: artist.name};
    final genresByAlbum = await _loadGenres(albums);

    final playCounts = <String, int>{};
    final lastPlayedAt = <String, DateTime>{};
    final validPlays = <Play>[];

    for (final play in plays) {
      if (!albumIds.contains(play.albumId)) continue;
      validPlays.add(play);
      playCounts.update(play.albumId, (count) => count + 1, ifAbsent: () => 1);

      final parsed = DateTime.tryParse(play.playedAt)?.toUtc();
      if (parsed == null) continue;
      final previous = lastPlayedAt[play.albumId];
      if (previous == null || parsed.isAfter(previous)) {
        lastPlayedAt[play.albumId] = parsed;
      }
    }

    final tasteProfile = _buildTasteProfile(
      validPlays,
      albums,
      genresByAlbum,
      playCounts,
    );
    final now = _now().toUtc();

    final rediscover = _buildRediscover(
      albums: albums,
      artistsById: artistsById,
      genresByAlbum: genresByAlbum,
      playCounts: playCounts,
      lastPlayedAt: lastPlayedAt,
      now: now,
      threshold: rediscoverThreshold,
      limit: sectionLimit,
    );
    final rediscoverIds = rediscover.map((item) => item.album.id).toSet();

    final genrePicks = _buildGenrePicks(
      albums: albums,
      artistsById: artistsById,
      genresByAlbum: genresByAlbum,
      playCounts: playCounts,
      lastPlayedAt: lastPlayedAt,
      tasteProfile: tasteProfile,
      now: now,
      recentSuppression: recentSuppression,
      excludedAlbumIds: rediscoverIds,
      limit: sectionLimit,
    );
    final usedIds = <String>{
      ...rediscoverIds,
      ...genrePicks.map((item) => item.album.id),
    };

    final eraPicks = _buildEraPicks(
      albums: albums,
      artistsById: artistsById,
      genresByAlbum: genresByAlbum,
      playCounts: playCounts,
      lastPlayedAt: lastPlayedAt,
      tasteProfile: tasteProfile,
      now: now,
      recentSuppression: recentSuppression,
      excludedAlbumIds: usedIds,
      limit: sectionLimit,
    );

    final occupied = {...usedIds, ...eraPicks.map((item) => item.album.id)};
    final underplayed = <AlbumRecommendation>[];
    for (final album in albums) {
      final count = playCounts[album.id] ?? 0;
      final last = lastPlayedAt[album.id];
      if (occupied.contains(album.id) ||
          count > 2 ||
          _isRecent(last, now, recentSuppression)) {
        continue;
      }
      // Unknown play dates must not bypass the recent-play guard.
      if (count > 0 && last == null) continue;
      underplayed.add(
        AlbumRecommendation(
          album: album,
          artistName: artistsById[album.artistId] ?? 'Unknown artist',
          genres: _genreNames(genresByAlbum[album.id]),
          reason: count == 0
              ? _unplayedReason(album.createdAt)
              : '${_playCountLabel(count)} • '
                    '${_formatLastPlayed(last!, now)}',
          kind: RecommendationKind.underplayed,
          playCount: count,
          score: 2 - count,
          lastPlayedAt: last,
        ),
      );
    }
    underplayed.sort((left, right) {
      final byCount = left.playCount.compareTo(right.playCount);
      if (byCount != 0) return byCount;
      return _compareAlbums(left.album, right.album);
    });

    return DiscoverRecommendations(
      collectionSize: albums.length,
      tasteProfile: tasteProfile,
      rediscover: List.unmodifiable(rediscover),
      genrePicks: List.unmodifiable(genrePicks),
      eraPicks: List.unmodifiable(eraPicks),
      underplayed: List.unmodifiable(underplayed.take(sectionLimit)),
    );
  }

  Future<Map<String, List<Genre>>> _loadGenres(List<Album> albums) async {
    final assignments = await Future.wait([
      for (final album in albums) _loadAlbumGenres(album.id),
    ]);
    return {
      for (final assignment in assignments)
        assignment.albumId: assignment.genres,
    };
  }

  Future<_AlbumGenres> _loadAlbumGenres(String albumId) async {
    return _AlbumGenres(
      albumId: albumId,
      genres: await _genreRepository.findByAlbum(albumId),
    );
  }

  TasteProfile? _buildTasteProfile(
    List<Play> plays,
    List<Album> albums,
    Map<String, List<Genre>> genresByAlbum,
    Map<String, int> playCounts,
  ) {
    if (plays.isEmpty) return null;

    final albumsById = {for (final album in albums) album.id: album};
    final genreCounts = <String, _GenreCount>{};
    final decadeCounts = <int, int>{};

    for (final play in plays) {
      final album = albumsById[play.albumId];
      if (album == null) continue;

      for (final genre in genresByAlbum[album.id] ?? const <Genre>[]) {
        final previous = genreCounts[genre.id];
        genreCounts[genre.id] = _GenreCount(
          genre: genre,
          playCount: (previous?.playCount ?? 0) + 1,
        );
      }

      final releaseYear = album.releaseYear;
      if (releaseYear != null && releaseYear > 0) {
        final decade = (releaseYear ~/ 10) * 10;
        decadeCounts.update(decade, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    final totalGenreAttributions = genreCounts.values.fold<int>(
      0,
      (total, item) => total + item.playCount,
    );
    final topGenres =
        [
          for (final item in genreCounts.values)
            TasteGenre(
              genre: item.genre,
              playCount: item.playCount,
              share: totalGenreAttributions == 0
                  ? 0
                  : item.playCount / totalGenreAttributions,
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

    final decades = decadeCounts.entries.toList()
      ..sort((left, right) {
        final byCount = right.value.compareTo(left.value);
        if (byCount != 0) return byCount;
        return left.key.compareTo(right.key);
      });

    return TasteProfile(
      totalPlays: plays.length,
      playedAlbums: playCounts.length,
      topGenres: List.unmodifiable(topGenres.take(5)),
      favoriteDecade: decades.isEmpty ? null : decades.first.key,
      favoriteDecadePlayCount: decades.isEmpty ? 0 : decades.first.value,
    );
  }

  List<AlbumRecommendation> _buildRediscover({
    required List<Album> albums,
    required Map<String, String> artistsById,
    required Map<String, List<Genre>> genresByAlbum,
    required Map<String, int> playCounts,
    required Map<String, DateTime> lastPlayedAt,
    required DateTime now,
    required Duration threshold,
    required int limit,
  }) {
    final candidates = <AlbumRecommendation>[];

    for (final album in albums) {
      final lastPlayed = lastPlayedAt[album.id];
      if (lastPlayed == null) continue;
      final elapsed = now.difference(lastPlayed);
      if (elapsed.isNegative || elapsed.compareTo(threshold) < 0) continue;

      final count = playCounts[album.id] ?? 0;
      candidates.add(
        AlbumRecommendation(
          album: album,
          artistName: artistsById[album.artistId] ?? 'Unknown artist',
          genres: _genreNames(genresByAlbum[album.id]),
          reason:
              '${_playCountLabel(count)} • '
              '${_formatLastPlayed(lastPlayed, now)}',
          kind: RecommendationKind.rediscover,
          playCount: count,
          score: elapsed.inDays,
          lastPlayedAt: lastPlayed,
        ),
      );
    }

    candidates.sort((left, right) {
      final leftLast = left.lastPlayedAt!;
      final rightLast = right.lastPlayedAt!;
      final byLastPlayed = leftLast.compareTo(rightLast);
      if (byLastPlayed != 0) return byLastPlayed;
      final byPlays = right.playCount.compareTo(left.playCount);
      if (byPlays != 0) return byPlays;
      return _compareAlbums(left.album, right.album);
    });

    return candidates.take(limit).toList(growable: false);
  }

  List<AlbumRecommendation> _buildGenrePicks({
    required List<Album> albums,
    required Map<String, String> artistsById,
    required Map<String, List<Genre>> genresByAlbum,
    required Map<String, int> playCounts,
    required Map<String, DateTime> lastPlayedAt,
    required TasteProfile? tasteProfile,
    required DateTime now,
    required Duration recentSuppression,
    required Set<String> excludedAlbumIds,
    required int limit,
  }) {
    if (tasteProfile == null || tasteProfile.topGenres.isEmpty) {
      return const [];
    }

    final tasteByGenreId = {
      for (final taste in tasteProfile.topGenres) taste.genre.id: taste,
    };
    final candidates = <AlbumRecommendation>[];

    for (final album in albums) {
      if (excludedAlbumIds.contains(album.id)) continue;
      if (_isRecent(lastPlayedAt[album.id], now, recentSuppression)) continue;

      final albumGenres = genresByAlbum[album.id] ?? const <Genre>[];
      final matches = <TasteGenre>[];
      for (final genre in albumGenres) {
        final taste = tasteByGenreId[genre.id];
        if (taste != null) matches.add(taste);
      }
      if (matches.isEmpty) continue;

      matches.sort((left, right) {
        final byCount = right.playCount.compareTo(left.playCount);
        if (byCount != 0) return byCount;
        return left.genre.name.toLowerCase().compareTo(
          right.genre.name.toLowerCase(),
        );
      });
      final score = matches.fold<int>(
        0,
        (total, match) => total + match.playCount,
      );
      final strongest = matches.first;
      final count = playCounts[album.id] ?? 0;

      candidates.add(
        AlbumRecommendation(
          album: album,
          artistName: artistsById[album.artistId] ?? 'Unknown artist',
          genres: _genreNames(albumGenres),
          reason:
              '${strongest.genre.name} appears in '
              '${strongest.playCount} of your logged plays • '
              '${_candidateHistory(count, lastPlayedAt[album.id], now)}',
          kind: RecommendationKind.genre,
          playCount: count,
          score: score,
          lastPlayedAt: lastPlayedAt[album.id],
        ),
      );
    }

    candidates.sort((left, right) {
      final byScore = right.score.compareTo(left.score);
      if (byScore != 0) return byScore;
      final byPlays = left.playCount.compareTo(right.playCount);
      if (byPlays != 0) return byPlays;
      return _compareAlbums(left.album, right.album);
    });

    return candidates.take(limit).toList(growable: false);
  }

  List<AlbumRecommendation> _buildEraPicks({
    required List<Album> albums,
    required Map<String, String> artistsById,
    required Map<String, List<Genre>> genresByAlbum,
    required Map<String, int> playCounts,
    required Map<String, DateTime> lastPlayedAt,
    required TasteProfile? tasteProfile,
    required DateTime now,
    required Duration recentSuppression,
    required Set<String> excludedAlbumIds,
    required int limit,
  }) {
    final favoriteDecade = tasteProfile?.favoriteDecade;
    final favoriteDecadePlayCount = tasteProfile?.favoriteDecadePlayCount ?? 0;
    if (favoriteDecade == null) return const [];

    final candidates = <AlbumRecommendation>[];
    for (final album in albums) {
      if (excludedAlbumIds.contains(album.id)) continue;
      if (_isRecent(lastPlayedAt[album.id], now, recentSuppression)) continue;

      final releaseYear = album.releaseYear;
      if (releaseYear == null || (releaseYear ~/ 10) * 10 != favoriteDecade) {
        continue;
      }

      candidates.add(
        AlbumRecommendation(
          album: album,
          artistName: artistsById[album.artistId] ?? 'Unknown artist',
          genres: _genreNames(genresByAlbum[album.id]),
          reason:
              '$favoriteDecadePlayCount of your logged '
              '${favoriteDecadePlayCount == 1 ? 'play comes' : 'plays come'} '
              'from ${favoriteDecade}s records • '
              '${_candidateHistory(playCounts[album.id] ?? 0, lastPlayedAt[album.id], now)}',
          kind: RecommendationKind.era,
          playCount: playCounts[album.id] ?? 0,
          score: 1,
          lastPlayedAt: lastPlayedAt[album.id],
        ),
      );
    }

    candidates.sort((left, right) {
      final byPlays = left.playCount.compareTo(right.playCount);
      if (byPlays != 0) return byPlays;
      return _compareAlbums(left.album, right.album);
    });

    return candidates.take(limit).toList(growable: false);
  }

  bool _isRecent(DateTime? lastPlayed, DateTime now, Duration suppression) {
    if (lastPlayed == null) return false;
    final elapsed = now.difference(lastPlayed);
    return elapsed.isNegative || elapsed.compareTo(suppression) < 0;
  }

  int _compareAlbums(Album left, Album right) {
    final byTitle = left.title.toLowerCase().compareTo(
      right.title.toLowerCase(),
    );
    if (byTitle != 0) return byTitle;
    return left.id.compareTo(right.id);
  }

  List<String> _genreNames(List<Genre>? genres) {
    if (genres == null || genres.isEmpty) return const [];
    final names = genres.map((genre) => genre.name).toList()
      ..sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
      );
    return List.unmodifiable(names);
  }

  String _formatLastPlayed(DateTime lastPlayed, DateTime now) {
    final elapsed = now.difference(lastPlayed);
    final days = elapsed.inDays;
    final relative = switch (days) {
      0 => 'today',
      1 => 'yesterday',
      < 60 => '$days days ago',
      < 365 => '${days ~/ 30} ${days ~/ 30 == 1 ? 'month' : 'months'} ago',
      _ => '${days ~/ 365} ${days ~/ 365 == 1 ? 'year' : 'years'} ago',
    };
    return 'Last played ${_formatCalendarDate(lastPlayed)} ($relative)';
  }

  String _playCountLabel(int count) =>
      '$count ${count == 1 ? 'play' : 'plays'} logged';

  String _candidateHistory(int count, DateTime? lastPlayed, DateTime now) {
    if (count == 0) return 'No plays logged for this record';
    if (lastPlayed == null) return _playCountLabel(count);
    return '${_playCountLabel(count)} • '
        '${_formatLastPlayed(lastPlayed, now)}';
  }

  String _unplayedReason(String createdAt) {
    final addedAt = DateTime.tryParse(createdAt)?.toUtc();
    if (addedAt == null) {
      return 'No plays logged yet — give this record a first spin';
    }
    return 'Added ${_formatCalendarDate(addedAt)} • No plays logged yet';
  }

  String _formatCalendarDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

@riverpod
IRecommendationService recommendationService(Ref ref) {
  return RecommendationService(
    albumRepository: ref.watch(albumRepositoryProvider),
    artistRepository: ref.watch(artistRepositoryProvider),
    playRepository: ref.watch(playRepositoryProvider),
    genreRepository: ref.watch(genreRepositoryProvider),
  );
}

@riverpod
Future<DiscoverRecommendations> discoverRecommendations(Ref ref) {
  return ref.watch(recommendationServiceProvider).getRecommendations();
}

class _AlbumGenres {
  const _AlbumGenres({required this.albumId, required this.genres});

  final String albumId;
  final List<Genre> genres;
}

class _GenreCount {
  const _GenreCount({required this.genre, required this.playCount});

  final Genre genre;
  final int playCount;
}
