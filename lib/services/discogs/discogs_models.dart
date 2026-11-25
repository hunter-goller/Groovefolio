class DiscogsAccount {
  const DiscogsAccount({
    required this.id,
    required this.username,
    this.resourceUrl,
  });
  final int id;
  final String username;
  final String? resourceUrl;
}

/// One candidate pressing; selecting it still requires fetching exact
/// release details before a local record is created.
class DiscogsReleaseSearchResult {
  const DiscogsReleaseSearchResult({
    required this.releaseId,
    required this.title,
    required this.artist,
    this.year,
    this.label,
    this.country,
    this.formats = const [],
    this.coverImageUrl,
  });

  final int releaseId;
  final String title;
  final String artist;
  final int? year;
  final String? label;
  final String? country;
  final List<String> formats;
  final String? coverImageUrl;

  String get subtitleParts {
    final values = <String>[
      if (year != null) year.toString(),
      if (label != null && label!.isNotEmpty) label!,
      if (country != null && country!.isNotEmpty) country!,
      if (formats.isNotEmpty) formats.join(', '),
    ];
    return values.join(' • ');
  }
}

class DiscogsTrack {
  const DiscogsTrack({
    required this.title,
    required this.sequence,
    this.position,
    this.side,
    this.durationSeconds,
  });

  final String title;
  final int sequence;
  final String? position;
  final String? side;
  final int? durationSeconds;
}

/// Normalized metadata for one exact Discogs release, including track order.
class DiscogsReleaseDetails {
  const DiscogsReleaseDetails({
    required this.releaseId,
    required this.title,
    required this.artist,
    this.year,
    this.label,
    this.genres = const [],
    this.styles = const [],
    this.artworkUrl,
    this.tracks = const [],
  });

  final int releaseId;
  final String title;
  final String artist;
  final int? year;
  final String? label;
  final List<String> genres;
  final List<String> styles;
  final String? artworkUrl;
  final List<DiscogsTrack> tracks;

  /// Combines Discogs genres and styles, keeping the first spelling of each
  /// case-insensitive name for the local genre repository.
  List<String> get genreNames {
    final seen = <String>{};
    final values = <String>[];
    for (final value in [...genres, ...styles]) {
      final normalized = value.trim();
      if (normalized.isEmpty || !seen.add(normalized.toLowerCase())) continue;
      values.add(normalized);
    }
    return values;
  }
}

class DiscogsCollectionItem {
  const DiscogsCollectionItem({
    required this.releaseId,
    required this.instanceId,
    required this.title,
    required this.artist,
    this.year,
    this.label,
    this.formats = const [],
    this.coverImageUrl,
  });

  final int releaseId;
  final int instanceId;
  final String title;
  final String artist;
  final int? year;
  final String? label;
  final List<String> formats;
  final String? coverImageUrl;

  bool get isVinyl =>
      formats.any((format) => format.trim().toLowerCase() == 'vinyl');
}

class DiscogsCollectionPage {
  const DiscogsCollectionPage({
    required this.items,
    required this.page,
    required this.pages,
    required this.totalItems,
  });

  final List<DiscogsCollectionItem> items;
  final int page;
  final int pages;
  final int totalItems;

  bool get hasNextPage => page < pages;
}

sealed class DiscogsFailure implements Exception {
  const DiscogsFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class DiscogsAuthenticationFailure extends DiscogsFailure {
  const DiscogsAuthenticationFailure(super.message);
}

class DiscogsRateLimitFailure extends DiscogsFailure {
  const DiscogsRateLimitFailure(super.message, {this.retryAfter});

  final Duration? retryAfter;
}

class DiscogsNetworkFailure extends DiscogsFailure {
  const DiscogsNetworkFailure(super.message);
}

class DiscogsApiFailure extends DiscogsFailure {
  const DiscogsApiFailure(super.message, {this.statusCode});
  final int? statusCode;
}
