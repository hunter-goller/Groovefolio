class DiscogsOAuthCredentials {
  const DiscogsOAuthCredentials({
    required this.token,
    required this.tokenSecret,
  });
  final String token;
  final String tokenSecret;
}

class DiscogsRequestToken {
  const DiscogsRequestToken({required this.token, required this.tokenSecret});
  final String token;
  final String tokenSecret;
}

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
  });

  final int releaseId;
  final String title;
  final String artist;
  final int? year;
  final String? label;
  final List<String> genres;
  final List<String> styles;
  final String? artworkUrl;

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

DiscogsReleaseSearchResult? discogsReleaseSearchResultFromJson(
  Map<String, dynamic> json,
) {
  final id = json['id'];
  final combinedTitle = _nonEmptyString(json['title']);
  if (id is! int || combinedTitle == null) return null;

  final titleParts = _splitSearchTitle(combinedTitle);
  return DiscogsReleaseSearchResult(
    releaseId: id,
    artist: titleParts.$1,
    title: titleParts.$2,
    year: _asInt(json['year']),
    label: _firstString(json['label']),
    country: _nonEmptyString(json['country']),
    formats: _stringList(json['format']),
    coverImageUrl: _nonEmptyString(json['cover_image']),
  );
}

DiscogsReleaseDetails discogsReleaseDetailsFromJson(
  Map<String, dynamic> json, {
  required int releaseId,
}) {
  final title = _nonEmptyString(json['title']);
  if (title == null) {
    throw const DiscogsApiFailure('Discogs release is missing a title.');
  }

  final artistNames = <String>[];
  final artists = json['artists'];
  if (artists is List) {
    for (final value in artists.whereType<Map<String, dynamic>>()) {
      final name = _nonEmptyString(value['name']);
      if (name != null) artistNames.add(_stripArtistDisambiguation(name));
    }
  }

  String? label;
  final labels = json['labels'];
  if (labels is List) {
    for (final value in labels.whereType<Map<String, dynamic>>()) {
      label = _nonEmptyString(value['name']);
      if (label != null) break;
    }
  }

  String? artworkUrl;
  final images = json['images'];
  if (images is List) {
    Map<String, dynamic>? fallback;
    for (final value in images.whereType<Map<String, dynamic>>()) {
      fallback ??= value;
      if (value['type'] == 'primary') {
        artworkUrl =
            _nonEmptyString(value['uri']) ??
            _nonEmptyString(value['resource_url']);
        break;
      }
    }
    artworkUrl ??= fallback == null
        ? null
        : _nonEmptyString(fallback['uri']) ??
              _nonEmptyString(fallback['resource_url']);
  }

  return DiscogsReleaseDetails(
    releaseId: releaseId,
    title: title,
    artist: artistNames.isEmpty ? 'Unknown Artist' : artistNames.join(', '),
    year: _asInt(json['year']),
    label: label,
    genres: _stringList(json['genres']),
    styles: _stringList(json['styles']),
    artworkUrl: artworkUrl,
  );
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
  const DiscogsRateLimitFailure(super.message);
}

class DiscogsNetworkFailure extends DiscogsFailure {
  const DiscogsNetworkFailure(super.message);
}

class DiscogsApiFailure extends DiscogsFailure {
  const DiscogsApiFailure(super.message, {this.statusCode});
  final int? statusCode;
}

(String, String) _splitSearchTitle(String value) {
  final separator = value.indexOf(' - ');
  if (separator <= 0 || separator >= value.length - 3) {
    return ('Unknown Artist', value);
  }
  return (
    _stripArtistDisambiguation(value.substring(0, separator).trim()),
    value.substring(separator + 3).trim(),
  );
}

String _stripArtistDisambiguation(String value) {
  return value.replaceFirst(RegExp(r' \(\d+\)$'), '').trim();
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

String? _firstString(Object? value) {
  final values = _stringList(value);
  return values.isEmpty ? null : values.first;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
