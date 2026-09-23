import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';
import 'package:vinyl_app/widgets/shared/genre_chip.dart';
import 'package:vinyl_app/widgets/shared/resilient_image.dart';

/// Compact Collection row matching the approved Groovefolio mockup.
class AlbumListTile extends StatelessWidget {
  const AlbumListTile({
    required this.title,
    required this.artist,
    required this.playCount,
    required this.onTap,
    this.onLongPress,
    this.releaseYear,
    this.artworkPath,
    this.lastPlayedAt,
    this.genres = const <String>[],
    super.key,
  });

  final String title;
  final String artist;
  final int playCount;
  final int? releaseYear;
  final String? artworkPath;
  final DateTime? lastPlayedAt;
  final List<String> genres;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lastPlayedLabel = _relativeTimeLabel(lastPlayedAt) ?? 'Not played';
    final playLabel = playCount == 1 ? '1 play' : '$playCount plays';

    return Semantics(
      button: true,
      label: '$title by $artist',
      onLongPress: onLongPress,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.space8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AlbumArtwork(path: artworkPath),
                SizedBox(width: tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.titleSmall?.copyWith(
                          color: tokens.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: tokens.space4),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                      if (genres.isNotEmpty) ...[
                        SizedBox(height: tokens.space4),
                        Wrap(
                          key: const Key('album-list-genres'),
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
                SizedBox(width: tokens.space8),
                SizedBox(
                  width: 76,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lastPlayedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: context.theme.textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                      SizedBox(height: tokens.space4),
                      Text(
                        playLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: context.theme.textTheme.labelMedium?.copyWith(
                          color: context.theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.space4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
      ),
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          color: AppThemeTokens.accent,
          size: 24,
        ),
      ),
    );

    return SizedBox.square(
      dimension: 58,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        child: normalizedPath == null || normalizedPath.isEmpty
            ? placeholder
            : ResilientImage.file(
                path: normalizedPath,
                fallback: placeholder,
                operation: 'load collection album artwork',
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

String? _relativeTimeLabel(DateTime? date) {
  if (date == null) return null;

  final difference = DateTime.now().toUtc().difference(date.toUtc());
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays == 1) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  if (difference.inDays < 35) return '${difference.inDays ~/ 7}w ago';
  return '${difference.inDays ~/ 30}mo ago';
}
