import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/providers/genre_providers.dart';
import 'package:vinyl_app/providers/track_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/services/album_deletion_service.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';
import 'package:vinyl_app/types/side_played.dart';
import 'package:vinyl_app/widgets/shared/genre_chip.dart';
import 'package:vinyl_app/widgets/ui/empty_state.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';
import 'package:vinyl_app/widgets/ui/section_header.dart';

/// Album detail screen aligned with the richer approved mockup while using
/// only metadata currently backed by the local database.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(albumDetailProvider(albumId));
    final genresAsync = ref.watch(albumGenresProvider(albumId));
    final tracksAsync = ref.watch(albumTracksProvider(albumId));
    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(AppRoutes.collection);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => _goBack(context)),
          title: const Text('Album Details'),
          actions: [
            PopupMenuButton<_AlbumMenuAction>(
              tooltip: 'Record actions',
              onSelected: (action) {
                switch (action) {
                  case _AlbumMenuAction.edit:
                    context.push(AppRoutes.editAlbumPath(albumId));
                  case _AlbumMenuAction.delete:
                    _confirmDelete(context, ref);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _AlbumMenuAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit record'),
                  ),
                ),
                PopupMenuItem(
                  value: _AlbumMenuAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete record'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _DetailError(
              onRetry: () => ref.invalidate(albumDetailProvider(albumId)),
            ),
            data: (detail) {
              if (detail == null) {
                return EmptyState(
                  icon: Icons.album_outlined,
                  title: 'Record not found',
                  subtitle:
                      'This record may have been removed from your collection.',
                  ctaLabel: 'Back to collection',
                  onCtaTap: () => context.go(AppRoutes.collection),
                );
              }

              final genres =
                  genresAsync.value
                      ?.map((genre) => genre.name)
                      .toList(growable: false) ??
                  const <String>[];
              final tracks = tracksAsync.value ?? const <Track>[];

              return _AlbumDetailBody(
                detail: detail,
                genres: genres,
                tracks: tracks,
                onLogPlay: () => _openLogPlay(context, ref, detail),
              );
            },
          ),
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(AppRoutes.collection);
    }
  }

  Future<void> _openLogPlay(
    BuildContext context,
    WidgetRef ref,
    AlbumDetailData detail,
  ) async {
    final tokens = context.tokens;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: tokens.background,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: LogPlayScreen(
            isBottomSheet: true,
            initialAlbum: detail.collectionAlbum,
          ),
        ),
      ),
    );
    ref.invalidate(albumDetailProvider(detail.album.id));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    try {
      final detail = await ref.read(albumDetailProvider(albumId).future);
      if (detail == null || !context.mounted) return;

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

      if (confirmed != true || !context.mounted) return;

      await ref.read(albumDeletionServiceProvider).deleteAlbum(albumId);

      ref.invalidate(albumsProvider);
      ref.invalidate(albumProvider(albumId));
      ref.invalidate(albumDetailProvider(albumId));
      ref.invalidate(albumGenresProvider(albumId));
      ref.invalidate(albumTracksProvider(albumId));
      ref.invalidate(recentlyPlayedProvider);

      if (!context.mounted) return;
      context.go(AppRoutes.collection);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn’t delete record: $error')));
    }
  }
}

enum _AlbumMenuAction { edit, delete }

class _AlbumDetailBody extends StatelessWidget {
  const _AlbumDetailBody({
    required this.detail,
    required this.genres,
    required this.tracks,
    required this.onLogPlay,
  });

  final AlbumDetailData detail;
  final List<String> genres;
  final List<Track> tracks;
  final Future<void> Function() onLogPlay;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final recentPlays = detail.plays.take(8).toList(growable: false);

    return ListView(
      key: const PageStorageKey<String>('album-detail-list'),
      padding: EdgeInsets.fromLTRB(
        tokens.space16,
        tokens.space8,
        tokens.space16,
        tokens.space32,
      ),
      children: [
        _AlbumHero(detail: detail, genres: genres),
        SizedBox(height: tokens.space24),
        _DetailSection(detail: detail, genres: genres),
        SizedBox(height: tokens.space16),
        _TracklistSection(tracks: tracks),
        SizedBox(height: tokens.space16),
        _ListeningSummary(detail: detail),
        SizedBox(height: tokens.space16),
        PrimaryButton(
          label: detail.playCount == 0 ? 'Log first play' : 'Log another play',
          icon: Icons.play_arrow_rounded,
          onPressed: () async => onLogPlay(),
        ),
        SizedBox(height: tokens.space24),
        SectionHeader(
          title: 'Recent plays',
          trailing: detail.playCount == 1
              ? '1 play'
              : '${detail.playCount} plays',
        ),
        if (recentPlays.isEmpty)
          const _NoPlayHistory()
        else
          for (var index = 0; index < recentPlays.length; index++) ...[
            _PlayHistoryTile(play: recentPlays[index]),
            if (index != recentPlays.length - 1)
              SizedBox(height: tokens.space8),
          ],
      ],
    );
  }
}

class _AlbumHero extends StatelessWidget {
  const _AlbumHero({required this.detail, required this.genres});

  final AlbumDetailData detail;
  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final album = detail.album;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AlbumArtwork(path: album.artworkPath),
        SizedBox(width: tokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                album.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.headlineSmall?.copyWith(
                  color: tokens.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: tokens.space4),
              Text(
                detail.artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.titleMedium?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
              if (album.releaseYear != null) ...[
                SizedBox(height: tokens.space8),
                _MetaLine(label: 'Year', value: '${album.releaseYear}'),
              ],
              if (album.label?.trim().isNotEmpty ?? false) ...[
                SizedBox(height: tokens.space4),
                _MetaLine(label: 'Label', value: album.label!.trim()),
              ],
              if (genres.isNotEmpty) ...[
                SizedBox(height: tokens.space8),
                Wrap(
                  key: const Key('album-detail-genres'),
                  spacing: tokens.space4,
                  runSpacing: tokens.space4,
                  children: [
                    for (final genre in genres) GenreChip(genre: genre),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return RichText(
      text: TextSpan(
        style: context.theme.textTheme.bodySmall?.copyWith(color: tokens.text),
        children: [
          TextSpan(
            text: '$label\n',
            style: TextStyle(color: tokens.textMuted, fontSize: 10),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.detail, required this.genres});
  final AlbumDetailData detail;
  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final album = detail.album;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETAILS',
          style: context.theme.textTheme.labelSmall?.copyWith(
            color: tokens.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: tokens.space8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(tokens.radiusMedium),
          ),
          child: Column(
            children: [
              if (album.label?.trim().isNotEmpty ?? false)
                _DetailRow(label: 'Label', value: album.label!.trim()),
              if (album.releaseYear != null)
                _DetailRow(
                  label: 'Release year',
                  value: '${album.releaseYear}',
                ),
              if (genres.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.space12,
                    vertical: tokens.space12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 92,
                        child: Text(
                          'Genres',
                          style: context.theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: tokens.space4,
                          runSpacing: tokens.space4,
                          children: [
                            for (final genre in genres) GenreChip(genre: genre),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space12,
        vertical: tokens.space12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: context.theme.textTheme.bodySmall?.copyWith(
              color: tokens.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TracklistSection extends StatelessWidget {
  const _TracklistSection({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      key: const Key('album-detail-tracklist'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRACKLIST',
          style: context.theme.textTheme.labelSmall?.copyWith(
            color: tokens.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: tokens.space8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(tokens.radiusMedium),
          ),
          child: tracks.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(tokens.space16),
                  child: Text(
                    'No tracklist available for this record.',
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                )
              : _TrackRows(tracks: tracks),
        ),
      ],
    );
  }
}

class _TrackRows extends StatelessWidget {
  const _TrackRows({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final hasSides = tracks.any((track) => track.side?.trim().isNotEmpty ?? false);
    if (!hasSides) {
      return Column(
        children: [
          for (var index = 0; index < tracks.length; index++) ...[
            _TrackRow(track: tracks[index]),
            if (index != tracks.length - 1) const Divider(height: 1),
          ],
        ],
      );
    }

    final children = <Widget>[];
    String? currentSide;
    for (final track in tracks) {
      final side = track.side?.trim().toUpperCase();
      if (side != currentSide) {
        if (children.isNotEmpty) children.add(const Divider(height: 1));
        children.add(_TrackSideHeader(side: side));
        currentSide = side;
      }
      children.add(_TrackRow(track: track));
    }
    return Column(children: children);
  }
}

class _TrackSideHeader extends StatelessWidget {
  const _TrackSideHeader({required this.side});

  final String? side;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space12,
        tokens.space12,
        tokens.space12,
        tokens.space4,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          side == null ? 'Tracks' : 'Side $side',
          style: context.theme.textTheme.labelLarge?.copyWith(
            color: tokens.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final position = track.position?.trim();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space12,
        vertical: tokens.space8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              position?.isNotEmpty == true ? position! : '${track.sequence + 1}',
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              track.title,
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: tokens.text,
              ),
            ),
          ),
          if (track.durationSeconds != null) ...[
            SizedBox(width: tokens.space8),
            Text(
              _formatTrackDuration(track.durationSeconds!),
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatTrackDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork({this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final normalizedPath = path?.trim();
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          color: AppThemeTokens.accent,
          size: 54,
        ),
      ),
    );
    return SizedBox.square(
      dimension: 142,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        child: normalizedPath == null || normalizedPath.isEmpty
            ? placeholder
            : Image.file(
                File(normalizedPath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

class _ListeningSummary extends StatelessWidget {
  const _ListeningSummary({required this.detail});
  final AlbumDetailData detail;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR STATS',
          style: context.theme.textTheme.labelSmall?.copyWith(
            color: tokens.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: tokens.space8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(tokens.radiusMedium),
          ),
          child: Column(
            children: [
              _DetailRow(label: 'Times played', value: '${detail.playCount}'),
              _DetailRow(
                label: 'Last played',
                value: _relativeTimeLabel(detail.lastPlayedAt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayHistoryTile extends StatelessWidget {
  const _PlayHistoryTile({required this.play});
  final Play play;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final playedAt = DateTime.tryParse(play.playedAt)?.toLocal();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space12,
          vertical: tokens.space12,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(tokens.space8),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: context.theme.colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
            SizedBox(width: tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sideLabel(play.sidePlayed),
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                  Text(
                    playedAt == null
                        ? 'Unknown time'
                        : _playDateLabel(context, playedAt),
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPlayHistory extends StatelessWidget {
  const _NoPlayHistory();
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space16),
        child: Row(
          children: [
            Icon(Icons.history_rounded, color: tokens.textMuted),
            SizedBox(width: tokens.space12),
            Expanded(
              child: Text(
                'No plays logged yet. Your listening history will appear here.',
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Couldn’t load this record',
      subtitle: 'Something went wrong while reading your local collection.',
      ctaLabel: 'Try again',
      onCtaTap: onRetry,
    );
  }
}

String _sideLabel(SidePlayed side) => switch (side) {
  SidePlayed.full => 'Full album',
  SidePlayed.sideA => 'Side A',
  SidePlayed.sideB => 'Side B',
};

String _relativeTimeLabel(DateTime? date) {
  if (date == null) return 'Never';
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays == 1) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  if (difference.inDays < 35) return '${difference.inDays ~/ 7}w ago';
  return '${difference.inDays ~/ 30}mo ago';
}

String _playDateLabel(BuildContext context, DateTime date) {
  final localizations = MaterialLocalizations.of(context);
  final dateLabel = localizations.formatMediumDate(date);
  final timeLabel = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date));
  return '$dateLabel • $timeLabel';
}
