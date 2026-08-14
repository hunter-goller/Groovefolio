import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinyl_app/db/app_database.dart';
import 'package:vinyl_app/providers/repository_providers.dart';

/// All canonical genres available for pickers and genre-management UI.
final genresProvider = FutureProvider.autoDispose<List<Genre>>((ref) {
  return ref.watch(genreRepositoryProvider).findAll();
});

/// Genres assigned to one album.
final albumGenresProvider = FutureProvider.autoDispose
    .family<List<Genre>, String>((ref, albumId) {
      final normalizedAlbumId = albumId.trim();
      if (normalizedAlbumId.isEmpty) return Future.value(const <Genre>[]);

      return ref.watch(genreRepositoryProvider).findByAlbum(normalizedAlbumId);
    });
