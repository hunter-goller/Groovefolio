# Dependency graph

## Local data path

```text
Collection / Add / Edit / Detail / Log Play / Stats
                       ↓
        album/genre/stat feature providers
                       ↓
     services where workflows need coordination
                       ↓
AlbumRepository  ArtistRepository  PlayRepository
GenreRepository  NfcTagRepository
                       ↓
                 AppDatabase
                       ↓
                    SQLite
```

## Filesystem path

```text
Add/Edit artwork UI
      ↓
ArtworkPicker
      ↓
ArtworkStorageService
      ↓
application documents/artwork/<albumId>.jpg
```

## Delete path

```text
Album Detail → AlbumDeletionService
                   ├─ PlayRepository
                   ├─ NfcTagRepository
                   ├─ ArtworkStorageService
                   └─ AlbumRepository
```

`AlbumGenres` mappings are removed by database cascade when the album row is deleted.

## Discogs Part 1

```text
discogsAccountProvider
        ↓
DiscogsAuthService
        ├─ DiscogsCredentialStore → flutter_secure_storage
        └─ DiscogsApiClient
                ↓
        DiscogsOAuthSigner
                ↓
             Discogs
```

Part 2 will connect the auth service to Settings/browser/deep-link UI.
