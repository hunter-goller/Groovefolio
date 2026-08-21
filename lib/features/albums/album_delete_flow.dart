import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/providers/track_providers.dart';
import 'package:vinyl_app/services/album_deletion_service.dart';

/// Shows the canonical record-delete confirmation and, when confirmed,
/// delegates deletion to [AlbumDeletionService].
///
/// Both Album Detail and Collection quick actions use this helper so there is
/// one destructive confirmation path and one provider-invalidation policy.
Future<bool> confirmAndDeleteAlbum(
  BuildContext context,
  WidgetRef ref,
  String albumId,
) async {
  try {
    final detail = await ref.read(albumDetailProvider(albumId).future);
    if (detail == null || !context.mounted) return false;

    final playLabel = detail.playCount == 1
        ? '1 play'
        : '${detail.playCount} plays';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${detail.album.title}?'),
        content: Text(
          'This will also delete all $playLabel logged for this record. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            key: const Key('delete-record-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('delete-record-confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    await ref.read(albumDeletionServiceProvider).deleteAlbum(albumId);

    ref.invalidate(albumsProvider);
    ref.invalidate(albumProvider(albumId));
    ref.invalidate(albumDetailProvider(albumId));
    ref.invalidate(albumGenresProvider(albumId));
    ref.invalidate(albumTracksProvider(albumId));
    ref.invalidate(recentlyPlayedProvider);

    return true;
  } catch (error) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Couldn’t delete record: $error')));
    return false;
  }
}
