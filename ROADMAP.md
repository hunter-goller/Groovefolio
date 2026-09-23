# Groovefolio roadmap

Groovefolio is an unreleased Android-first, local-first vinyl app. This page tracks broad milestones; [implementation status](docs/implementation-status.md) describes the code on `main`. Ticket-level status lives on the [Vinyl App Dev board](https://trello.com/b/e9B7pkq8/vinyl-app-dev). Historical ticket IDs keep the `VinylApp-###` prefix.

## Implemented in the app

- Collection management, local artwork, genres, manual plays, and schema v1–v6.
- Stats for current-year and all-time listening.
- On-device Discover recommendations and explanation sheets.
- Optional Discogs OAuth, search/autofill, barcode lookup, reviewed collection import, and tracklists.
- NFC tag management and automatic play handling; device validation remains a release task.
- Interactive onboarding, Settings, privacy/support links, branding, launcher icon, and splash.
- Permanent Android application ID `app.groovefolio` and release signing configuration.

## Before a public Play release

- Create/backup the real upload keystore and verify the signed AAB locally (`VinylApp-074`).
- Complete Play account, listing/screenshots, data disclosures, and internal testing (`VinylApp-073/088/089/131`).
- Verify permissions, offline behavior, migrations, NFC hardware behavior, and website release QA (`VinylApp-123`).
- Resolve the production Discogs consumer secret and OAuth architecture. The proposed Java/Spring Boot backend is separate, unmerged, and undeployed (`VinylApp-125`).
- Point the website download CTA at the actual Play listing when the listing is ready (`VinylApp-124`).

## Later ideas

External discovery of records not owned, optional affiliate links, yearly Wrapped, and side A/B listening breakdown. Broad accessibility work is deferred, while readable text and reduced-motion behavior should remain intact. See the board for scope and priority.

## Product principles

Collection data stays on the device as the source of truth. The core app works without a network account; external services are optional enhancements.