import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vinyl_app/services/discogs/discogs_models.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

/// Which form a draft belongs to. There's one slot for each.
enum RecordDraftKind { add, edit }

/// What someone had typed on Add record or Edit record, kept so it survives
/// Android closing the app in the background, a crash, or a swipe-away.
@immutable
class RecordDraft {
  const RecordDraft({
    this.albumId,
    this.title = '',
    this.artist = '',
    this.year = '',
    this.label = '',
    this.genres = const [],
    this.artworkPath,
    this.discogsArtworkPath,
    this.discogsReleaseId,
    this.discogsTracks = const [],
    this.nfc = false,
    this.savedAt,
  });

  /// The record being edited; null on Add record.
  final String? albumId;
  final String title;
  final String artist;
  final String year;
  final String label;
  final List<String> genres;

  /// A cover picked from the phone.
  final String? artworkPath;

  /// A cover downloaded from Discogs, not yet saved with the record.
  final String? discogsArtworkPath;
  final int? discogsReleaseId;
  final List<DiscogsTrack> discogsTracks;

  /// Add: write an NFC tag after saving. Edit: rewrite the tag.
  final bool nfc;
  final DateTime? savedAt;

  /// Drafts older than this are dropped rather than offered.
  static const maxAge = Duration(days: 14);

  /// A short name for prompts: the title, else the artist.
  String get name {
    final value = title.trim().isNotEmpty ? title.trim() : artist.trim();
    return value.isEmpty ? 'a record' : '“$value”';
  }

  /// Whether anything has been entered at all (Add record).
  bool get isBlank =>
      title.trim().isEmpty &&
      artist.trim().isEmpty &&
      year.trim().isEmpty &&
      label.trim().isEmpty &&
      genres.isEmpty &&
      artworkPath == null &&
      discogsArtworkPath == null &&
      discogsReleaseId == null &&
      !nfc;

  /// Same form contents, ignoring when it was saved.
  bool sameContentAs(RecordDraft other) =>
      jsonEncode(_content()) == jsonEncode(other._content());

  Map<String, Object?> _content() => {
    'albumId': albumId,
    'title': title,
    'artist': artist,
    'year': year,
    'label': label,
    'genres': genres,
    'artworkPath': artworkPath,
    'discogsArtworkPath': discogsArtworkPath,
    'discogsReleaseId': discogsReleaseId,
    'discogsTracks': [
      for (final track in discogsTracks)
        {
          'title': track.title,
          'sequence': track.sequence,
          'position': track.position,
          'side': track.side,
          'durationSeconds': track.durationSeconds,
        },
    ],
    'nfc': nfc,
  };

  Map<String, Object?> toJson() => {
    'version': 1,
    ..._content(),
    'savedAt': (savedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };

  /// Null when [json] isn't a draft this version understands.
  static RecordDraft? fromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['version'] != 1) return null;
    try {
      return RecordDraft(
        albumId: json['albumId'] as String?,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        year: json['year'] as String? ?? '',
        label: json['label'] as String? ?? '',
        genres: [...(json['genres'] as List? ?? const []).cast<String>()],
        artworkPath: json['artworkPath'] as String?,
        discogsArtworkPath: json['discogsArtworkPath'] as String?,
        discogsReleaseId: json['discogsReleaseId'] as int?,
        discogsTracks: [
          for (final track in (json['discogsTracks'] as List? ?? const []))
            DiscogsTrack(
              title: (track as Map)['title'] as String,
              sequence: track['sequence'] as int,
              position: track['position'] as String?,
              side: track['side'] as String?,
              durationSeconds: track['durationSeconds'] as int?,
            ),
        ],
        nfc: json['nfc'] as bool? ?? false,
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? ''),
      );
    } on TypeError {
      return null;
    }
  }
}

/// Where drafts are kept. Every method is best-effort: a draft that can't be
/// read or written must never get in the way of the form itself.
abstract interface class RecordDraftStore {
  Future<RecordDraft?> read(RecordDraftKind kind);
  Future<void> write(RecordDraftKind kind, RecordDraft draft);
  Future<void> delete(RecordDraftKind kind);
}

/// Keeps each draft as a small JSON file in the app's private support folder.
class FileRecordDraftStore implements RecordDraftStore {
  FileRecordDraftStore({
    Future<Directory> Function()? directory,
    DateTime Function()? now,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _now;

  Future<File> _file(RecordDraftKind kind) async {
    final base = await _directory();
    return File(p.join(base.path, 'record_drafts', '${kind.name}.json'));
  }

  @override
  Future<RecordDraft?> read(RecordDraftKind kind) async {
    try {
      final file = await _file(kind);
      if (!await file.exists()) return null;
      RecordDraft? draft;
      try {
        draft = RecordDraft.fromJson(jsonDecode(await file.readAsString()));
      } on FormatException {
        draft = null; // Damaged: dropped below.
      }
      final savedAt = draft?.savedAt;
      if (draft == null ||
          savedAt == null ||
          _now().difference(savedAt) > RecordDraft.maxAge) {
        await file.delete();
        return null;
      }
      return draft;
    } catch (error, stackTrace) {
      logAppError('read record draft', error, stackTrace);
      return null;
    }
  }

  @override
  Future<void> write(RecordDraftKind kind, RecordDraft draft) async {
    try {
      final file = await _file(kind);
      await file.parent.create(recursive: true);
      // Write then rename, so a crash mid-write never leaves half a draft.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(draft.toJson()), flush: true);
      await temp.rename(file.path);
    } catch (error, stackTrace) {
      logAppError('save record draft', error, stackTrace);
    }
  }

  @override
  Future<void> delete(RecordDraftKind kind) async {
    try {
      final file = await _file(kind);
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      logAppError('delete record draft', error, stackTrace);
    }
  }
}

final recordDraftStoreProvider = Provider<RecordDraftStore>(
  (ref) => FileRecordDraftStore(),
);
