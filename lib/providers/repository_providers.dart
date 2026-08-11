// Central import surface for repository dependencies.
//
// The repository providers are introduced alongside their repositories so
// each repository remains independently testable. VinylApp-016 collects the
// four provider contracts here so feature and service code has one stable
// import without duplicating provider definitions.
export 'package:vinyl_app/repositories/album_repository.dart'
    show IAlbumRepository, albumRepositoryProvider;
export 'package:vinyl_app/repositories/artist_repository.dart'
    show IArtistRepository, artistRepositoryProvider;
export 'package:vinyl_app/repositories/nfc_tag_repository.dart'
    show INfcTagRepository, nfcTagRepositoryProvider;
export 'package:vinyl_app/repositories/play_repository.dart'
    show IPlayRepository, playRepositoryProvider;
