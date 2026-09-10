import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';

part 'recommendation_service.g.dart';

enum RecommendationKind { rediscover, genre, era, underplayed }

class RecommendationEvidence {
  const RecommendationEvidence({required this.title, required this.detail});

  final String title;
  final String detail;
}

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

class TasteArtist {
  const TasteArtist({
    required this.artistId,
    required this.name,
    required this.playCount,
    required this.recentPlayCount,
  });

  final String artistId;
  final String name;
  final int playCount;
  final int recentPlayCount;
}

class TasteProfile {
  const TasteProfile({
    required this.totalPlays,
    required this.playedAlbums,
    required this.topGenres,
    required this.favoriteDecade,
    this.favoriteDecadePlayCount = 0,
    this.recentPlayCount = 0,
    this.recentWindowDays = 90,
    this.recentTopGenres = const [],
    this.topArtists = const [],
  });

  final int totalPlays;
  final int playedAlbums;
  final List<TasteGenre> topGenres;
  final int? favoriteDecade;
  final int favoriteDecadePlayCount;
  final int recentPlayCount;
  final int recentWindowDays;
  final List<TasteGenre> recentTopGenres;
  final List<TasteArtist> topArtists;
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
    this.evidence = const [],
  });

  final Album album;
  final String artistName;
  final List<String> genres;
  final String reason;
  final RecommendationKind kind;
  final int playCount;
  final int score;
  final DateTime? lastPlayedAt;
  final List<RecommendationEvidence> evidence;
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
    Duration recentTasteWindow = const Duration(days: 90),
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
    Duration recentTasteWindow = const Duration(days: 90),
    int sectionLimit = 6,
  }) async {
    if (sectionLimit <= 0) {
      throw ArgumentError.value(
        sectionLimit,
        'sectionLimit',
        'Section limit must be greater than zero.',
      );
    }
    if (recentTasteWindow <= Duration.zero) {
      throw ArgumentError.value(
        recentTasteWindow,
        'recentTasteWindow',
        'Recent taste window must be greater than zero.',
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

    final now = _now().toUtc();
    final playCounts = <String, int>{};
    final recentPlayCounts = <String, int>{};
    final lastPlayedAt = <String, DateTime>{};
    final validPlays = <Play>[];

    for (final play in plays) {
      if (!albumIds.contains(play.albumId)) continue;
      validPlays.add(play);
      playCounts.update(play.albumId, (count) => count + 1, ifAbsent: () => 1);

      final parsed = DateTime.tryParse(play.playedAt)?.toUtc();
      if (parsed == null) continue;
      final elapsed = now.difference(parsed);
      if (!elapsed.isNegative && elapsed.compareTo(recentTasteWindow) < 0) {
        recentPlayCounts.update(
          play.albumId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      final previous = lastPlayedAt[play.albumId];
      if (previous == null || parsed.isAfter(previous)) {
        lastPlayedAt[play.albumId] = parsed;
      }
    }

    final tasteProfile = _buildTasteProfile(
      validPlays,
      albums,
      artistsById,
      genresByAlbum,
      playCounts,
      now,
      recentTasteWindow,
    );

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

    final genrePicks = _buildTastePicks(
      albums: albums,
      artistsById: artistsById,
      genresByAlbum: genresByAlbum,
      playCounts: playCounts,
      recentPlayCounts: recentPlayCounts,
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
          evidence: _rotationEvidence(album, count, last, now),
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
    Map<String, String> artistsById,
    Map<String, List<Genre>> genresByAlbum,
    Map<String, int> playCounts,
    DateTime now,
    Duration recentTasteWindow,
  ) {
    if (plays.isEmpty) return null;

    final albumsById = {for (final album in albums) album.id: album};
    final genreCounts = <String, _GenreCount>{};
    final recentGenreCounts = <String, _GenreCount>{};
    final artistCounts = <String, _ArtistCount>{};
    final decadeCounts = <int, int>{};
    var recentPlayCount = 0;

    for (final play in plays) {
      final album = albumsById[play.albumId];
      if (album == null) continue;
      final playedAt = DateTime.tryParse(play.playedAt)?.toUtc();
      final elapsed = playedAt == null ? null : now.difference(playedAt);
      final isRecent =
          elapsed != null &&
          !elapsed.isNegative &&
          elapsed.compareTo(recentTasteWindow) < 0;
      if (isRecent) recentPlayCount += 1;

      final previousArtist = artistCounts[album.artistId];
      artistCounts[album.artistId] = _ArtistCount(
        artistId: album.artistId,
        name: artistsById[album.artistId] ?? 'Unknown artist',
        playCount: (previousArtist?.playCount ?? 0) + 1,
        recentPlayCount:
            (previousArtist?.recentPlayCount ?? 0) + (isRecent ? 1 : 0),
      );

      for (final genre in genresByAlbum[album.id] ?? const <Genre>[]) {
        final previous = genreCounts[genre.id];
        genreCounts[genre.id] = _GenreCount(
          genre: genre,
          playCount: (previous?.playCount ?? 0) + 1,
        );
        if (isRecent) {
          final recentPrevious = recentGenreCounts[genre.id];
          recentGenreCounts[genre.id] = _GenreCount(
            genre: genre,
            playCount: (recentPrevious?.playCount ?? 0) + 1,
          );
        }
      }

      final releaseYear = album.releaseYear;
      if (releaseYear != null && releaseYear > 0) {
        final decade = (releaseYear ~/ 10) * 10;
        decadeCounts.update(decade, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    final topGenres = _rankTasteGenres(genreCounts);
    final recentTopGenres = _rankTasteGenres(recentGenreCounts);
    final topArtists =
        [
          for (final item in artistCounts.values)
            TasteArtist(
              artistId: item.artistId,
              name: item.name,
              playCount: item.playCount,
              recentPlayCount: item.recentPlayCount,
            ),
        ]..sort((left, right) {
          final leftStrength = left.playCount * 8 + left.recentPlayCount * 18;
          final rightStrength =
              right.playCount * 8 + right.recentPlayCount * 18;
          final byStrength = rightStrength.compareTo(leftStrength);
          if (byStrength != 0) return byStrength;
          final byRecent = right.recentPlayCount.compareTo(
            left.recentPlayCount,
          );
          if (byRecent != 0) return byRecent;
          final byPlays = right.playCount.compareTo(left.playCount);
          if (byPlays != 0) return byPlays;
          final byName = left.name.toLowerCase().compareTo(
            right.name.toLowerCase(),
          );
          if (byName != 0) return byName;
          return left.artistId.compareTo(right.artistId);
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
      recentPlayCount: recentPlayCount,
      recentWindowDays: recentTasteWindow.inDays,
      recentTopGenres: List.unmodifiable(recentTopGenres.take(5)),
      topArtists: List.unmodifiable(topArtists.take(5)),
    );
  }

  List<TasteGenre> _rankTasteGenres(Map<String, _GenreCount> counts) {
    final totalAttributions = counts.values.fold<int>(
      0,
      (total, item) => total + item.playCount,
    );
    return [
      for (final item in counts.values)
        TasteGenre(
          genre: item.genre,
          playCount: item.playCount,
          share: totalAttributions == 0
              ? 0
              : item.playCount / totalAttributions,
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
          evidence: [
            RecommendationEvidence(
              title: 'Play history',
              detail: _playCountLabel(count),
            ),
            RecommendationEvidence(
              title: 'Time away',
              detail: _formatLastPlayed(lastPlayed, now),
            ),
          ],
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

  List<AlbumRecommendation> _buildTastePicks({
    required List<Album> albums,
    required Map<String, String> artistsById,
    required Map<String, List<Genre>> genresByAlbum,
    required Map<String, int> playCounts,
    required Map<String, int> recentPlayCounts,
    required Map<String, DateTime> lastPlayedAt,
    required TasteProfile? tasteProfile,
    required DateTime now,
    required Duration recentSuppression,
    required Set<String> excludedAlbumIds,
    required int limit,
  }) {
    if (tasteProfile == null) return const [];

    final allTimeGenres = {
      for (final taste in tasteProfile.topGenres) taste.genre.id: taste,
    };
    final recentGenres = {
      for (final taste in tasteProfile.recentTopGenres) taste.genre.id: taste,
    };
    final artists = {
      for (final taste in tasteProfile.topArtists) taste.artistId: taste,
    };
    final candidates = <AlbumRecommendation>[];

    for (final album in albums) {
      if (excludedAlbumIds.contains(album.id)) continue;
      if (_isRecent(lastPlayedAt[album.id], now, recentSuppression)) continue;

      final count = playCounts[album.id] ?? 0;
      final recentCount = recentPlayCounts[album.id] ?? 0;
      final albumGenres = genresByAlbum[album.id] ?? const <Genre>[];
      final matches = <_GenreAffinity>[];
      for (final genre in albumGenres) {
        final allTime = allTimeGenres[genre.id];
        final recent = recentGenres[genre.id];
        final remainingAllTime = (allTime?.playCount ?? 0) - count;
        final remainingRecent = (recent?.playCount ?? 0) - recentCount;
        final supportingAllTime = remainingAllTime > 0 ? remainingAllTime : 0;
        final supportingRecent = remainingRecent > 0 ? remainingRecent : 0;
        if (supportingAllTime > 0 || supportingRecent > 0) {
          matches.add(
            _GenreAffinity(
              genre: genre,
              allTimePlays: supportingAllTime,
              recentPlays: supportingRecent,
            ),
          );
        }
      }
      matches.sort((left, right) {
        final byRecent = right.recentPlays.compareTo(left.recentPlays);
        if (byRecent != 0) return byRecent;
        final byAllTime = right.allTimePlays.compareTo(left.allTimePlays);
        if (byAllTime != 0) return byAllTime;
        return left.genre.name.toLowerCase().compareTo(
          right.genre.name.toLowerCase(),
        );
      });

      final artistName = artistsById[album.artistId] ?? 'Unknown artist';
      final artistProfile = artistName == 'Unknown artist'
          ? null
          : artists[album.artistId];
      final remainingArtistPlays = (artistProfile?.playCount ?? 0) - count;
      final remainingRecentArtistPlays =
          (artistProfile?.recentPlayCount ?? 0) - recentCount;
      final artistAllTime = remainingArtistPlays > 0 ? remainingArtistPlays : 0;
      final artistRecent = remainingRecentArtistPlays > 0
          ? remainingRecentArtistPlays
          : 0;
      final hasArtistAffinity = artistAllTime > 0 || artistRecent > 0;
      if (matches.isEmpty && !hasArtistAffinity) continue;

      var score = 0;
      for (final match in matches) {
        score += match.allTimePlays * 10 + match.recentPlays * 20;
      }
      if (hasArtistAffinity) {
        score += artistAllTime * 8 + artistRecent * 18;
      }

      final releaseYear = album.releaseYear;
      final favoriteDecade = tasteProfile.favoriteDecade;
      final matchesFavoriteEra =
          releaseYear != null &&
          favoriteDecade != null &&
          (releaseYear ~/ 10) * 10 == favoriteDecade;
      final remainingEraPlays = matchesFavoriteEra
          ? tasteProfile.favoriteDecadePlayCount - count
          : 0;
      final supportingEraPlays = remainingEraPlays > 0 ? remainingEraPlays : 0;
      if (supportingEraPlays > 0) {
        score += supportingEraPlays * 4;
      }

      score += (count < 3 ? 3 - count : 0) * 3;
      final strongest = matches.isEmpty ? null : matches.first;
      final evidence = <RecommendationEvidence>[];

      for (final match in matches.take(3)) {
        final recentDetail = match.recentPlays == 0
            ? ''
            : ', including ${match.recentPlays} in the last '
                  '${tasteProfile.recentWindowDays} days';
        evidence.add(
          RecommendationEvidence(
            title: match.recentPlays > 0
                ? 'Recent ${match.genre.name} match'
                : '${match.genre.name} match',
            detail:
                '${match.genre.name} appears in '
                '${match.allTimePlays} logged plays$recentDetail.',
          ),
        );
      }
      if (hasArtistAffinity) {
        final recentDetail = artistRecent == 0
            ? ''
            : ' $artistRecent were in the last '
                  '${tasteProfile.recentWindowDays} days.';
        evidence.add(
          RecommendationEvidence(
            title: 'Artist affinity',
            detail:
                'Other $artistName records appear in $artistAllTime of '
                'your logged plays.$recentDetail',
          ),
        );
      }
      if (supportingEraPlays > 0) {
        evidence.add(
          RecommendationEvidence(
            title: 'Era match',
            detail:
                '$supportingEraPlays other logged '
                '${supportingEraPlays == 1 ? 'play comes' : 'plays come'} '
                'from ${favoriteDecade}s records.',
          ),
        );
      }
      evidence.add(
        RecommendationEvidence(
          title: 'This record',
          detail: _candidateHistory(count, lastPlayedAt[album.id], now),
        ),
      );

      final lead = switch ((strongest?.recentPlays ?? 0, artistRecent)) {
        (> 0, _) => 'Recent ${strongest!.genre.name} match',
        (_, > 0) => 'Recent $artistName listening',
        _ when hasArtistAffinity => 'You often play $artistName',
        _ => 'Matches your ${strongest!.genre.name} history',
      };

      candidates.add(
        AlbumRecommendation(
          album: album,
          artistName: artistName,
          genres: _genreNames(albumGenres),
          reason: '$lead • ${_shortPlayHistory(count)}',
          kind: RecommendationKind.genre,
          playCount: count,
          score: score,
          lastPlayedAt: lastPlayedAt[album.id],
          evidence: List.unmodifiable(evidence),
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
      final count = playCounts[album.id] ?? 0;
      final supportingEraPlays = favoriteDecadePlayCount - count;
      if (supportingEraPlays <= 0) continue;

      candidates.add(
        AlbumRecommendation(
          album: album,
          artistName: artistsById[album.artistId] ?? 'Unknown artist',
          genres: _genreNames(genresByAlbum[album.id]),
          reason:
              '$supportingEraPlays of your other logged '
              '${supportingEraPlays == 1 ? 'play comes' : 'plays come'} '
              'from ${favoriteDecade}s records • '
              '${_candidateHistory(count, lastPlayedAt[album.id], now)}',
          kind: RecommendationKind.era,
          playCount: count,
          score: supportingEraPlays,
          lastPlayedAt: lastPlayedAt[album.id],
          evidence: [
            RecommendationEvidence(
              title: 'Era match',
              detail:
                  '$supportingEraPlays other logged '
                  '${supportingEraPlays == 1 ? 'play comes' : 'plays come'} '
                  'from ${favoriteDecade}s records.',
            ),
            RecommendationEvidence(
              title: 'This record',
              detail: _candidateHistory(count, lastPlayedAt[album.id], now),
            ),
          ],
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

  String _shortPlayHistory(int count) {
    if (count == 0) return 'No plays logged';
    return _playCountLabel(count);
  }

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

  List<RecommendationEvidence> _rotationEvidence(
    Album album,
    int count,
    DateTime? lastPlayed,
    DateTime now,
  ) {
    final evidence = <RecommendationEvidence>[];
    final addedAt = DateTime.tryParse(album.createdAt)?.toUtc();
    if (addedAt != null) {
      evidence.add(
        RecommendationEvidence(
          title: 'Added to your collection',
          detail: _formatCalendarDate(addedAt),
        ),
      );
    }
    evidence.add(
      RecommendationEvidence(
        title: 'Play history',
        detail: _candidateHistory(count, lastPlayed, now),
      ),
    );
    return List.unmodifiable(evidence);
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

class _ArtistCount {
  const _ArtistCount({
    required this.artistId,
    required this.name,
    required this.playCount,
    required this.recentPlayCount,
  });

  final String artistId;
  final String name;
  final int playCount;
  final int recentPlayCount;
}

class _GenreAffinity {
  const _GenreAffinity({
    required this.genre,
    required this.allTimePlays,
    required this.recentPlays,
  });

  final Genre genre;
  final int allTimePlays;
  final int recentPlays;
}
