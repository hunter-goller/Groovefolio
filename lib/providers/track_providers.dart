import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';

/// Complete ordered tracklist for one album.
final albumTracksProvider = FutureProvider.autoDispose
    .family<List<Track>, String>((ref, albumId) {
      final normalizedAlbumId = albumId.trim();
      if (normalizedAlbumId.isEmpty) return Future.value(const <Track>[]);
      return ref.watch(trackRepositoryProvider).findByAlbum(normalizedAlbumId);
    });
