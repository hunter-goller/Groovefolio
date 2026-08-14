import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';
import 'package:vinyl_app/theme/tokens.dart';

/// Album search result used by the Log Play selection flow.
class AlbumSelectTile extends StatelessWidget {
  const AlbumSelectTile({
    required this.title,
    required this.artist,
    required this.playCount,
    required this.isSelected,
    required this.onTap,
    this.releaseYear,
    this.artworkPath,
    super.key,
  });

  final String title;
  final String artist;
  final int playCount;
  final bool isSelected;
  final VoidCallback onTap;
  final int? releaseYear;
  final String? artworkPath;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final playLabel = playCount == 1 ? '1 play' : '$playCount plays';
    final details = [
      if (releaseYear != null) '$releaseYear',
      playLabel,
    ].join('  •  ');

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title by $artist',
      child: Material(
        color: isSelected
            ? context.theme.colorScheme.primary.withValues(alpha: 0.12)
            : tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(tokens.space12),
            child: Row(
              children: [
                _Artwork(path: artworkPath),
                SizedBox(width: tokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.titleMedium?.copyWith(
                          color: tokens.text,
                          fontWeight: FontWeight.w700,
                        ),
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
                      SizedBox(height: tokens.space4),
                      Text(
                        details,
                        style: context.theme.textTheme.labelMedium?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.space8),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isSelected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: context.theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.path});

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
          size: 26,
        ),
      ),
    );

    return SizedBox.square(
      dimension: 56,
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
