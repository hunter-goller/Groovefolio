import 'package:flutter/material.dart';

/// Returns a deterministic palette slot for a genre name.
///
/// The same normalized name always maps to the same slot, which keeps genre
/// colors stable across Collection, Album Detail, Add Record, and Discover.
int genreColorIndex(String genre) {
  final normalized = genre.trim().toLowerCase();
  var hash = 17;
  for (final unit in normalized.codeUnits) {
    hash = ((hash * 31) + unit) & 0x7fffffff;
  }
  return hash % _genrePalette.length;
}

const _genrePalette = <Color>[
  Color(0xFF42A5F5), // blue
  Color(0xFFAB6BFF), // purple
  Color(0xFF40C878), // green
  Color(0xFFFFB52E), // amber
  Color(0xFF26C6DA), // cyan
  Color(0xFFEC6AA7), // pink
];

/// Small reusable genre pill used anywhere album genres are displayed.
class GenreChip extends StatelessWidget {
  const GenreChip({
    required this.genre,
    this.removable = false,
    this.onRemove,
    super.key,
  });

  final String genre;
  final bool removable;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final baseColor = _genrePalette[genreColorIndex(genre)];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? Color.lerp(baseColor, Colors.white, 0.16)!
        : Color.lerp(baseColor, Colors.black, 0.28)!;
    final borderRadius = BorderRadius.circular(10);

    final chip = ConstrainedBox(
      // Keep a single unusually long genre from forcing its parent to
      // overflow. Incoming constraints can still make the chip narrower;
      // the label will ellipsize while the remove affordance remains visible.
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: isDark ? 0.16 : 0.11),
          border: Border.all(color: baseColor.withValues(alpha: 0.52)),
          borderRadius: borderRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                genre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (removable) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 11, color: foreground),
            ],
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: removable
          ? InkWell(onTap: onRemove, borderRadius: borderRadius, child: chip)
          : chip,
    );
  }
}
