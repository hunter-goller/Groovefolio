/// Central definition of every route path in the app.
/// Screens and navigation calls should reference these constants,
/// never hardcode a path string directly.
abstract final class AppRoutes {
  static const collection = '/';
  static const stats = '/stats';
  static const discover = '/discover';
  static const addAlbum = '/album/new';
  static const albumDetail = '/album/:id';
  static const logPlay = '/play/log';

  /// Builds a concrete /album/{id} path for navigation calls,
  /// e.g. context.go(AppRoutes.albumDetailPath(album.id))
  static String albumDetailPath(String id) => '/album/$id';
}
