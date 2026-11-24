import 'dart:io';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// Tracks in-memory versions of artwork files that are overwritten in place.
///
/// Artwork keeps a stable path (`artwork/<albumId>.jpg`), so a plain
/// [FileImage] for a replaced cover is equal to the old one: Flutter's image
/// cache, and any screen still showing it, would keep the old picture until
/// the app restarts. [ArtworkFileImage] includes this version in its identity,
/// so bumping it makes every screen load the new file.
abstract final class ArtworkVersions {
  static final Map<String, int> _versions = {};

  static int of(String path) => _versions[path] ?? 0;

  /// Call after the file at [path] is written, restored or deleted.
  static void bump(String path) {
    final old = of(path);
    _versions[path] = old + 1;
    // Free the old decoded image; nothing will ask for that version again.
    // There is no image cache without a Flutter binding (plain unit tests).
    try {
      PaintingBinding.instance.imageCache.evict(
        ArtworkFileImage(File(path), version: old),
      );
    } on Object {
      // Nothing cached, so nothing to free.
    }
  }
}

/// A [FileImage] whose identity includes the file's [ArtworkVersions] version.
@immutable
class ArtworkFileImage extends FileImage {
  ArtworkFileImage(super.file, {int? version})
    : version = version ?? ArtworkVersions.of(file.path);

  final int version;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is ArtworkFileImage &&
      other.file.path == file.path &&
      other.scale == scale &&
      other.version == version;

  @override
  int get hashCode => Object.hash(file.path, scale, version);
}
