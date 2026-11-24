import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/services/onboarding_service.dart';

/// What the player has done in the tutorial. Badges are the completed tracks.
class TutorialProgressData {
  const TutorialProgressData({
    this.completed = const {},
    this.introSeen = false,
    this.goldCelebrated = false,
  });

  final Set<TutorialTrack> completed;
  final bool introSeen;
  final bool goldCelebrated;

  TutorialProgressData copyWith({
    Set<TutorialTrack>? completed,
    bool? introSeen,
    bool? goldCelebrated,
  }) => TutorialProgressData(
    completed: completed ?? this.completed,
    introSeen: introSeen ?? this.introSeen,
    goldCelebrated: goldCelebrated ?? this.goldCelebrated,
  );

  String toJson() => jsonEncode({
    'version': 1,
    'completed': [
      for (final track in TutorialTrack.values)
        if (completed.contains(track)) track.name,
    ],
    'introSeen': introSeen,
    'goldCelebrated': goldCelebrated,
  });

  /// Lenient: unknown track names (from a newer app) and wrong types are
  /// ignored rather than losing everything else.
  static TutorialProgressData fromJson(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const TutorialProgressData();
    }
    if (decoded is! Map<String, Object?>) return const TutorialProgressData();
    final names = decoded['completed'];
    return TutorialProgressData(
      completed: {
        if (names is List)
          for (final name in names)
            if (name is String) ?TutorialTrack.byName(name),
      },
      introSeen: decoded['introSeen'] == true,
      goldCelebrated: decoded['goldCelebrated'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TutorialProgressData &&
      other.introSeen == introSeen &&
      other.goldCelebrated == goldCelebrated &&
      other.completed.length == completed.length &&
      other.completed.containsAll(completed);

  @override
  int get hashCode => Object.hash(
    introSeen,
    goldCelebrated,
    Object.hashAllUnordered(completed),
  );
}

/// Stored on the device only, like the rest of Groovefolio. No account.
abstract interface class TutorialProgressStore {
  /// Null when nothing has been saved yet.
  Future<TutorialProgressData?> read();

  Future<void> write(TutorialProgressData data);
}

class SecureTutorialProgressStore implements TutorialProgressStore {
  const SecureTutorialProgressStore(this._storage);

  static const key = 'groovefolio.tutorial.progress.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<TutorialProgressData?> read() async {
    final raw = await _storage.read(key: key);
    return raw == null ? null : TutorialProgressData.fromJson(raw);
  }

  @override
  Future<void> write(TutorialProgressData data) =>
      _storage.write(key: key, value: data.toJson());
}

/// First-time read: carries over whether the old walkthrough was seen, so
/// existing users aren't shown the intro again. Old step numbers aren't
/// mapped to tracks (a step could be skipped); real data decides instead.
Future<TutorialProgressData> migrateFromWalkthrough(
  OnboardingStore legacy,
) async {
  final seen =
      await legacy.hasCompletedOnboarding() ||
      await legacy.readProgress() != null;
  return TutorialProgressData(introSeen: seen);
}

final tutorialProgressStoreProvider = Provider<TutorialProgressStore>(
  (ref) => const SecureTutorialProgressStore(FlutterSecureStorage()),
);
