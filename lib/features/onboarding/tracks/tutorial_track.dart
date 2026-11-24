import 'package:flutter/material.dart';

enum TutorialSide { a, b, bonus }

/// The tutorial's "tracks": short lessons played in any order. Finishing one
/// lights a groove on the progress record and earns its badge.
///
/// Persisted by [name], so never rename a value. Add new ones at the end.
enum TutorialTrack {
  addRecord(
    number: 1,
    side: TutorialSide.a,
    title: 'Add your first record',
    badge: 'Crate Starter',
    icon: Icons.library_add_rounded,
  ),
  logSpin(
    number: 2,
    side: TutorialSide.a,
    title: 'Log a spin',
    badge: 'First Spin',
    icon: Icons.play_circle_fill_rounded,
    needsRecord: true,
  ),
  stats(
    number: 3,
    side: TutorialSide.a,
    title: 'Check your stats',
    badge: 'Number Cruncher',
    icon: Icons.bar_chart_rounded,
  ),
  nfc(
    number: 4,
    side: TutorialSide.b,
    title: 'Tap to log with NFC',
    badge: 'Tap Master',
    icon: Icons.nfc_rounded,
    needsRecord: true,
    optional: true,
  ),
  swipe(
    number: 5,
    side: TutorialSide.b,
    title: 'Swipe for quick actions',
    badge: 'Smooth Operator',
    icon: Icons.swipe_left_rounded,
    needsRecord: true,
  ),
  backup(
    number: 6,
    side: TutorialSide.b,
    title: 'Back up your shelf',
    badge: 'Safe Keeper',
    icon: Icons.save_alt_rounded,
  ),
  discogsImport(
    number: 7,
    side: TutorialSide.bonus,
    title: 'Import from Discogs',
    badge: 'Crate Digger',
    icon: Icons.cloud_download_rounded,
    optional: true,
  );

  const TutorialTrack({
    required this.number,
    required this.side,
    required this.title,
    required this.badge,
    required this.icon,
    this.needsRecord = false,
    this.optional = false,
  });

  final int number;
  final TutorialSide side;
  final String title;
  final String badge;
  final IconData icon;

  /// Locked until the shelf has at least one record.
  final bool needsRecord;

  /// Earns a badge but isn't needed for the gold record. NFC needs a tag and
  /// hardware; Discogs needs an account. Neither should block anyone.
  final bool optional;

  static TutorialTrack? byName(String name) {
    for (final track in values) {
      if (track.name == name) return track;
    }
    return null;
  }
}
