import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/track_scripts.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_session.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_track.dart';
import 'package:vinyl_app/providers/repository_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';

/// One line under each track in the tracklist.
String trackBlurb(TutorialTrack track) => switch (track) {
  TutorialTrack.addRecord => 'Import from Discogs or type one in',
  TutorialTrack.logSpin => 'Tell Groovefolio what you just played',
  TutorialTrack.stats => 'See your listening, then Discover',
  TutorialTrack.nfc => 'Stick a tag on a sleeve, tap to log a play',
  TutorialTrack.swipe => 'Edit or remove a record in one move',
  TutorialTrack.backup => 'Save a copy somewhere safe',
  TutorialTrack.discogsImport => 'Bring in the collection you already have',
};

/// What to do right now, shown while a track is being played.
String trackHint(TutorialTrack track) => switch (track) {
  TutorialTrack.addRecord =>
    'Tap Add record, fill in a title and artist, then Save.',
  TutorialTrack.logSpin =>
    'Pick a record you’ve played, choose a side, then Save play.',
  TutorialTrack.stats => 'Look around your stats, then tap Discover.',
  TutorialTrack.nfc =>
    'Open the record menu (⋮), tap Link NFC tag and hold the tag to your phone.',
  TutorialTrack.swipe =>
    'Slide any record to the left to reveal Edit and Delete.',
  TutorialTrack.backup =>
    'Tap Back up collection and save it to Google Drive or Downloads.',
  TutorialTrack.discogsImport =>
    'Connect Discogs, then tap Import Discogs collection.',
};

/// Where [track] starts, and where "Show me" takes you back to.
String trackStartLocation(
  TutorialTrack track, {
  ShelfPath path = ShelfPath.byHand,
}) => switch (track) {
  TutorialTrack.addRecord =>
    path == ShelfPath.discogs ? AppRoutes.settings : AppRoutes.collection,
  TutorialTrack.logSpin => AppRoutes.logPlay,
  TutorialTrack.stats => AppRoutes.stats,
  TutorialTrack.nfc || TutorialTrack.swipe => AppRoutes.collection,
  TutorialTrack.backup => AppRoutes.collection,
  TutorialTrack.discogsImport => AppRoutes.settings,
};

/// Starts [track]: asks any up-front question, then sets it as the active
/// track and opens the right screen. Returns false if the user backed out.
///
/// [beforeStart] runs after the questions and before navigation, for
/// callers (like the welcome screen) whose own screen goes away on start.
Future<bool> startTrack(
  BuildContext context,
  WidgetRef ref,
  TutorialTrack track, {
  Future<void> Function()? beforeStart,
}) async {
  final router = GoRouter.of(context);
  var path = ShelfPath.byHand;
  String? location;

  switch (track) {
    case TutorialTrack.addRecord:
      final choice = await showModalBottomSheet<ShelfPath>(
        context: context,
        showDragHandle: true,
        builder: (_) => const _ShelfChoiceSheet(),
      );
      if (choice == null) return false;
      path = choice;
    case TutorialTrack.nfc:
      final ready = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _NfcIntroSheet(),
      );
      if (ready != true) return false;
      final albums = await ref.read(albumRepositoryProvider).findAll();
      if (albums.isNotEmpty) {
        location = AppRoutes.albumDetailPath(albums.first.id);
      }
    case TutorialTrack.logSpin:
    case TutorialTrack.stats:
    case TutorialTrack.swipe:
    case TutorialTrack.backup:
    case TutorialTrack.discogsImport:
      break;
  }

  location ??= trackStartLocation(track, path: path);
  await beforeStart?.call();
  ref.read(tutorialSessionProvider.notifier).play(track, path: path);
  // Tabs replace the stack; everything else opens on top so Back works.
  if (location == AppRoutes.collection || location == AppRoutes.stats) {
    router.go(location);
  } else {
    unawaited(router.push<void>(location));
  }
  return true;
}

class _ShelfChoiceSheet extends StatelessWidget {
  const _ShelfChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget option({
      required Key key,
      required IconData icon,
      required String title,
      required String subtitle,
      required ShelfPath value,
    }) => Card(
      child: ListTile(
        key: key,
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.pop(context, value),
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How do you want to fill your shelf?',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            option(
              key: const Key('shelf-choice-discogs'),
              icon: Icons.cloud_download_rounded,
              title: 'Import from Discogs',
              subtitle: 'You already catalogue your records there.',
              value: ShelfPath.discogs,
            ),
            option(
              key: const Key('shelf-choice-by-hand'),
              icon: Icons.edit_rounded,
              title: 'Add one by hand',
              subtitle: 'Type a title and artist. No account needed.',
              value: ShelfPath.byHand,
            ),
          ],
        ),
      ),
    );
  }
}

class _NfcIntroSheet extends StatelessWidget {
  const _NfcIntroSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget point(IconData icon, String line) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(line, style: text.bodyLarge)),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tap to log with NFC',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/help/tested-ntag215.jpg',
                height: 140,
                fit: BoxFit.cover,
                semanticLabel: 'NTAG215 NFC tags',
              ),
            ),
            const SizedBox(height: 14),
            point(
              Icons.sell_outlined,
              'Stick a small NFC tag on a record sleeve.',
            ),
            point(Icons.nfc_rounded, 'Tap your phone on it after you listen.'),
            point(
              Icons.check_circle_outline_rounded,
              'Groovefolio logs a full play, even when the app is closed.',
            ),
            const SizedBox(height: 4),
            Text(
              'You need one writable NFC tag (NTAG215 works). No tag yet? '
              'Skip and play this track later.',
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('nfc-intro-ready'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('I have a tag'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
