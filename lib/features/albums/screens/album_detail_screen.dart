import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/features/plays/screens/log_play_screen.dart';
import 'package:vinyl_app/providers/album_providers.dart';
import 'package:vinyl_app/routing/app_routes.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';
import 'package:vinyl_app/types/side_played.dart';
import 'package:vinyl_app/widgets/ui/empty_state.dart';
import 'package:vinyl_app/widgets/ui/primary_button.dart';
import 'package:vinyl_app/widgets/ui/section_header.dart';

/// MVP album detail page.
///
/// VinylApp-048 intentionally focuses on the core collection/listening loop:
/// identity, play-derived summary, recent history, and logging another play.
/// The richer Wrapped-style charts/recommendations remain separate follow-up
/// work once StatsService exists.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(albumDetailProvider(albumId));

    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.collection);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => _goBack(context)),
          title: const Text('Record details'),
          actions: [
            PopupMenuButton<_AlbumMenuAction>(
              tooltip: 'Record actions',
              onSelected: (action) => _showDeferredAction(context, action),
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

              return _AlbumDetailBody(
                detail: detail,
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
      return;
    }

    context.go(AppRoutes.collection);
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
      builder: (sheetContext) {
        return Padding(
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
        );
      },
    );

    ref.invalidate(albumDetailProvider(detail.album.id));
  }

  void _showDeferredAction(BuildContext context, _AlbumMenuAction action) {
    final feature = switch (action) {
      _AlbumMenuAction.edit => 'Edit record',
      _AlbumMenuAction.delete => 'Delete record',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }
}

enum _AlbumMenuAction { edit, delete }

class _AlbumDetailBody extends StatelessWidget {
  const _AlbumDetailBody({required this.detail, required this.onLogPlay});

  final AlbumDetailData detail;
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
        _AlbumIdentity(detail: detail),
        SizedBox(height: tokens.space24),
        _ListeningSummary(detail: detail),
        SizedBox(height: tokens.space24),
        PrimaryButton(
          label: detail.playCount == 0 ? 'Log first play' : 'Log another play',
          icon: Icons.play_arrow_rounded,
          onPressed: () async {
            await onLogPlay();
          },
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

class _AlbumIdentity extends StatelessWidget {
  const _AlbumIdentity({required this.detail});

  final AlbumDetailData detail;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final album = detail.album;
    final metadata = [
      if (album.releaseYear != null) '${album.releaseYear}',
      if (album.label?.trim().isNotEmpty ?? false) album.label!.trim(),
    ];

    return Column(
      children: [
        _AlbumArtwork(path: album.artworkPath),
        SizedBox(height: tokens.space16),
        Text(
          album.title,
          textAlign: TextAlign.center,
          style: context.theme.textTheme.headlineSmall?.copyWith(
            color: tokens.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: tokens.space4),
        Text(
          detail.artist.name,
          textAlign: TextAlign.center,
          style: context.theme.textTheme.titleMedium?.copyWith(
            color: tokens.textMuted,
          ),
        ),
        if (metadata.isNotEmpty) ...[
          SizedBox(height: tokens.space8),
          Text(
            metadata.join('  •  '),
            textAlign: TextAlign.center,
            style: context.theme.textTheme.labelLarge?.copyWith(
              color: context.theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
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
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
      ),
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          color: AppThemeTokens.accent,
          size: 72,
        ),
      ),
    );

    return SizedBox.square(
      dimension: 196,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
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

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'TOTAL PLAYS',
            value: '${detail.playCount}',
            icon: Icons.play_circle_outline_rounded,
          ),
        ),
        SizedBox(width: tokens.space12),
        Expanded(
          child: _MetricCard(
            label: 'LAST PLAYED',
            value: _relativeTimeLabel(detail.lastPlayedAt),
            icon: Icons.schedule_rounded,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        border: Border.all(color: tokens.textMuted.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.theme.colorScheme.primary, size: 20),
            SizedBox(height: tokens.space12),
            Text(
              label,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: tokens.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
            SizedBox(height: tokens.space4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.theme.textTheme.titleLarge?.copyWith(
                color: tokens.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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
    final side = play.sidePlayed;

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
                    _sideLabel(side),
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

String _sideLabel(SidePlayed side) {
  return switch (side) {
    SidePlayed.full => 'Full album',
    SidePlayed.sideA => 'Side A',
    SidePlayed.sideB => 'Side B',
  };
}

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
