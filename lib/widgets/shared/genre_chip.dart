import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

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
    final tokens = context.tokens;
    final borderRadius = BorderRadius.circular(12);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.textMuted.withValues(alpha: 0.28)),
        borderRadius: borderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              genre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: tokens.text,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (removable) ...[
            const SizedBox(width: 4),
            Icon(Icons.close_rounded, size: 10, color: tokens.textMuted),
          ],
        ],
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
