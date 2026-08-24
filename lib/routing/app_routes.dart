/// Central definition of every route path in the app.
/// Screens and navigation calls should reference these constants,
/// never hardcode a path string directly.
abstract final class AppRoutes {
  static const collection = '/';
  static const stats = '/stats';
  static const discover = '/discover';
  static const addAlbum = '/album/new';
  static const barcodeScan = '/album/barcode-scan';
  static const albumDetail = '/album/:id';
  static const editAlbum = '/album/:id/edit';
  static const logPlay = '/play/log';
  static const settings = '/settings';
  static const onboarding = '/onboarding';
  static const discogsCollectionImport = '/settings/discogs/import';

  /// Builds a concrete /album/{id} path for navigation calls,
  /// e.g. context.push(AppRoutes.albumDetailPath(album.id))
  static String albumDetailPath(String id) => '/album/$id';

  /// Builds a concrete /album/{id}/edit path for navigation calls.
  static String editAlbumPath(String id) => '/album/$id/edit';
}
