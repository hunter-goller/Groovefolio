# Implementation status

This page describes the app code on `main`, not unmerged backend branches or a public release. Check [roadmap](../ROADMAP.md) for remaining work.

## Available in the app

- Local collection add/edit/delete, search, genre filtering, artwork, Discogs release links and tracklists.
- Manual play logging, album history, and current-year/all-time Stats.
- On-device Discover recommendations with explanations derived from logged play history and records already owned.
- Optional Discogs OAuth connection, release search/autofill, barcode scanning, and reviewed collection import. The current app calls Discogs directly.
- Android NFC tag write/link/replace and automatic full-album play logging from a linked tag, with duplicate protection and foreground Undo or background notification/fallback.
- First-run interactive walkthrough and replay from Settings; privacy and support links.
- Riverpod, Drift/SQLite, go_router, and CI. Schema `v6` includes artists, albums, plays, NFC tags, genres, Discogs release links, tracks, cascade cleanup, and a play-history index. See [database](architecture/database.md).

## Release work still open

- Create and back up the real Android upload key on the developer's computer, then verify a signed AAB. CI uses a disposable key for compilation only.
- Validate NFC flows on physical hardware, including external tap behavior.
- Finalize store listing, screenshots, permissions/data disclosures, Play Console account and internal testing.
- Resolve production Discogs credential handling before public distribution. Backend work is in a separate repository and is not merged or deployed.
- Finish remaining release QA and verify the privacy policy against the actual shipped build.

Local collection, plays, Stats, and Discover do not require Discogs or a Groovefolio account. Android automatic backup is disabled; reinstall or phone replacement does not currently restore local collection data.