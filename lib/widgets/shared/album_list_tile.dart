import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';

/// Primary Collection row for one album.
class AlbumListTile extends StatelessWidget {
  const AlbumListTile({
    required this.title,
    required this.artist,
    required this.playCount,
    required this.onTap,
    this.releaseYear,
    this.artworkPath,
    this.lastPlayedAt,
    super.key,
  });

  final String title;
  final String artist;
  final int playCount;
  final int? releaseYear;
  final String? artworkPath;
  final DateTime? lastPlayedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final lastPlayedLabel = _relativeTimeLabel(lastPlayedAt);
    final playLabel = playCount == 1 ? '1 play' : '$playCount plays';
    final details = [
      if (releaseYear != null) '$releaseYear',
      playLabel,
    ].join('  •  ');

    return Semantics(
      button: true,
      label: '$title by $artist',
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(tokens.space12),
            child: Row(
              children: [
                _AlbumArtwork(path: artworkPath),
                SizedBox(width: tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.theme.textTheme.titleMedium
                                  ?.copyWith(
                                    color: tokens.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (lastPlayedLabel != null) ...[
                            SizedBox(width: tokens.space4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 72),
                              child: Text(
                                lastPlayedLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: context.theme.textTheme.labelSmall
                                    ?.copyWith(color: tokens.textMuted),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: tokens.space4),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                      SizedBox(height: tokens.space8),
                      Text(
                        details,
                        style: context.theme.textTheme.labelMedium?.copyWith(
                          color: context.theme.colorScheme.primary.withValues(
                            alpha: 0.82,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.space4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.textMuted,
                  size: 22,
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
          size: 28,
        ),
      ),
    );

    return SizedBox.square(
      dimension: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
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

String? _relativeTimeLabel(DateTime? date) {
  if (date == null) return null;

  final difference = DateTime.now().toUtc().difference(date.toUtc());
  if (difference.isNegative || difference.inMinutes < 1) {
    return 'Just now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays == 1) {
    return 'Yesterday';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }
  if (difference.inDays < 35) {
    return '${difference.inDays ~/ 7}w ago';
  }
  return '${difference.inDays ~/ 30}mo ago';
}
