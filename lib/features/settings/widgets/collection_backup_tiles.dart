import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/features/onboarding/tracks/spotlight/spotlight_target.dart';
import 'package:vinyl_app/features/onboarding/tracks/tutorial_session.dart';
import 'package:vinyl_app/features/stats/screens/stats_screen.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/providers/track_providers.dart';
import 'package:vinyl_app/services/backup/backup_file_gateway.dart';
import 'package:vinyl_app/services/backup/collection_backup_service.dart';
import 'package:vinyl_app/services/recommendation_service.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

/// Settings rows to back up the collection to a file and restore it.
class CollectionBackupTiles extends ConsumerStatefulWidget {
  const CollectionBackupTiles({super.key});

  @override
  ConsumerState<CollectionBackupTiles> createState() =>
      _CollectionBackupTilesState();
}

class _CollectionBackupTilesState extends ConsumerState<CollectionBackupTiles> {
  /// Disables both rows while a backup or restore is in progress.
  bool _busy = false;

  /// Shows the progress bar only while work runs, not behind a dialog.
  bool _working = false;

  void _setWorking(bool value) {
    if (mounted) setState(() => _working = value);
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _backUp() async {
    if (_busy) return;
    setState(() => _busy = _working = true);
    try {
      final service = ref.read(collectionBackupServiceProvider);
      final bytes = await service.createBackup();
      _setWorking(false);
      final saved = await ref
          .read(backupFileGatewayProvider)
          .save(service.suggestedFileName(), bytes);
      if (saved) {
        _show('Backup saved. Keep it somewhere safe.');
        ref.tutorialEvent(TutorialEvent.backupSaved);
      }
    } catch (error, stackTrace) {
      logAppError('create backup', error, stackTrace);
      _show('Couldn’t create the backup. Your collection is unchanged.');
    } finally {
      if (mounted) setState(() => _busy = _working = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(collectionBackupServiceProvider);
      if (!await service.isCollectionEmpty()) {
        await _showNotEmpty();
        return;
      }
      final bytes = await ref.read(backupFileGatewayProvider).open();
      if (bytes == null) return;
      final contents = service.readBackup(bytes);
      if (!await _confirm(contents.summary)) return;
      _setWorking(true);
      final result = await service.restore(contents);
      _refreshCollectionViews();
      _show(
        'Restored ${_count(result.albums, 'record')} and '
        '${_count(result.plays, 'play')}.',
      );
    } on BackupFormatException catch (error) {
      _show(error.message);
    } on BackupRestoreNotEmptyException {
      await _showNotEmpty();
    } catch (error, stackTrace) {
      logAppError('restore backup', error, stackTrace);
      _show('Couldn’t restore that backup. Nothing was changed.');
    } finally {
      if (mounted) setState(() => _busy = _working = false);
    }
  }

  void _refreshCollectionViews() {
    ref
      ..invalidate(albumsProvider)
      ..invalidate(albumSearchProvider)
      ..invalidate(albumProvider)
      ..invalidate(albumDetailProvider)
      ..invalidate(recentlyPlayedProvider)
      ..invalidate(playCountProvider)
      ..invalidate(genresProvider)
      ..invalidate(albumGenresProvider)
      ..invalidate(albumTracksProvider)
      ..invalidate(statsDashboardProvider)
      ..invalidate(discoverRecommendationsProvider);
  }

  Future<void> _showNotEmpty() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore needs an empty collection'),
        content: const Text(
          'Restoring is for a new phone or a fresh install, so it only works '
          'when your collection has no records. Nothing was changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(BackupSummary summary) async {
    if (!mounted) return false;
    final exported = summary.exportedAt;
    final date = exported == null
        ? ''
        : ' from ${exported.year}-${exported.month.toString().padLeft(2, '0')}'
              '-${exported.day.toString().padLeft(2, '0')}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'This backup$date has ${_count(summary.albums, 'record')}, '
          '${_count(summary.plays, 'play')} and '
          '${_count(summary.artworkFiles, 'cover')}.\n\n'
          'Discogs isn’t included. Reconnect it in Settings afterwards if you '
          'use it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-restore'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  static String _count(int value, String noun) =>
      '$value $noun${value == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SpotlightTarget(
          id: SpotlightId.backupTile,
          child: ListTile(
            key: const Key('backup-collection'),
            enabled: !_busy,
            leading: const Icon(Icons.save_alt_outlined),
            title: const Text('Back up collection'),
            subtitle: const Text(
              'Save a file with your records, plays and covers. Choose where '
              'it goes, such as Downloads or Google Drive.',
            ),
            onTap: _backUp,
          ),
        ),
        ListTile(
          key: const Key('restore-collection'),
          enabled: !_busy,
          leading: const Icon(Icons.settings_backup_restore_outlined),
          title: const Text('Restore from backup'),
          subtitle: const Text(
            'For a new phone or a fresh install. Works when your collection '
            'is empty.',
          ),
          onTap: _restore,
        ),
        if (_working) const LinearProgressIndicator(),
      ],
    );
  }
}
