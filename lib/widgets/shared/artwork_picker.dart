import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vinyl_app/theme/theme_helpers.dart';

/// Reusable artwork selection surface for Add/Edit Record.
///
/// This widget owns presentation only. The caller decides how artwork is picked
/// and persisted.
class ArtworkPicker extends StatelessWidget {
  const ArtworkPicker({
    required this.image,
    required this.onTap,
    this.size = 120,
    this.height,
    this.enabled = true,
    this.imageBuilder,
    super.key,
  });

  final File? image;
  final VoidCallback onTap;
  final double size;
  final double? height;
  final bool enabled;

  /// Optional renderer used by widget tests to avoid exercising Flutter's
  /// asynchronous file-image decoder. Production callers should leave this
  /// null so artwork is rendered with [Image.file].
  final Widget Function(File file)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final resolvedHeight = height ?? size;
    final hasImage = image != null && image!.existsSync();

    return Semantics(
      button: true,
      enabled: enabled,
      label: hasImage ? 'Change album artwork' : 'Add album artwork',
      child: SizedBox(
        width: size,
        height: resolvedHeight,
        child: Material(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tokens.radiusMedium),
                border: Border.all(
                  color: tokens.textMuted.withValues(alpha: 0.35),
                ),
              ),
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        imageBuilder?.call(image!) ??
                            Image.file(
                              image!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _ArtworkPlaceholder(enabled: enabled),
                            ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.68),
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _ArtworkPlaceholder(enabled: enabled),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, color: tokens.textMuted),
          const SizedBox(height: 8),
          Text(
            'Add art',
            style: context.theme.textTheme.labelMedium?.copyWith(
              color: tokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
