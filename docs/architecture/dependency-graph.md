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

## Discogs account connection

```text
SettingsScreen
   ├─ discogsAccountProvider
   └─ discogsAuthorizationControllerProvider
                ↓
        DiscogsAuthService
        ├─ DiscogsCredentialStore → flutter_secure_storage
        └─ DiscogsApiClient
                ↓
        DiscogsOAuthSigner
                ↓
             Discogs

app_links → groovefolio://discogs-auth → authorization controller → Settings
```
