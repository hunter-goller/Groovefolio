import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vinyl_app/utils/error_reporting.dart';

/// Image wrapper that replaces decode/load failures with a caller-provided
/// fallback and emits the underlying error only in debug builds.
class ResilientImage extends StatefulWidget {
  const ResilientImage({
    required this.image,
    required this.fallback,
    required this.operation,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.failureSemanticLabel = 'Image unavailable',
    super.key,
  });

  factory ResilientImage.file({
    required String path,
    required Widget fallback,
    required String operation,
    BoxFit? fit,
    double? width,
    double? height,
    AlignmentGeometry alignment = Alignment.center,
    FilterQuality filterQuality = FilterQuality.medium,
    String failureSemanticLabel = 'Album artwork unavailable',
    Key? key,
  }) {
    return ResilientImage(
      key: key,
      image: FileImage(File(path)),
      fallback: fallback,
      operation: operation,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      filterQuality: filterQuality,
      failureSemanticLabel: failureSemanticLabel,
    );
  }

  factory ResilientImage.memory({
    required Uint8List bytes,
    required Widget fallback,
    required String operation,
    BoxFit? fit,
    double? width,
    double? height,
    AlignmentGeometry alignment = Alignment.center,
    FilterQuality filterQuality = FilterQuality.medium,
    String failureSemanticLabel = 'Album artwork unavailable',
    Key? key,
  }) {
    return ResilientImage(
      key: key,
      image: MemoryImage(bytes),
      fallback: fallback,
      operation: operation,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      filterQuality: filterQuality,
      failureSemanticLabel: failureSemanticLabel,
    );
  }

  final ImageProvider<Object> image;
  final Widget fallback;
  final String operation;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final String failureSemanticLabel;

  @override
  State<ResilientImage> createState() => _ResilientImageState();
}

class _ResilientImageState extends State<ResilientImage> {
  bool _reportedFailure = false;

  @override
  void didUpdateWidget(covariant ResilientImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _reportedFailure = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: widget.image,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      errorBuilder: (context, error, stackTrace) {
        if (!_reportedFailure) {
          _reportedFailure = true;
          logAppError(widget.operation, error, stackTrace);
        }

        return Semantics(
          image: true,
          label: widget.failureSemanticLabel,
          child: ExcludeSemantics(child: widget.fallback),
        );
      },
    );
  }
}
