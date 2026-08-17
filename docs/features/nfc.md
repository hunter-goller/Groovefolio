# NFC

Groovefolio has the persistence foundation for NFC but not the production device flow yet.

## Implemented
- schema v2 `NfcTags`
- one unique tag per album / one album per physical tag constraint
- `NfcTagRepository`
- lookup by NFC tag ID and album ID
- delete association
- album deletion cleans up linked NFC association
- UI placeholders/prompts for future NFC behavior

## Still needed
- Android NFC permissions/manifest setup
- tag write service/flow
- scan handling
- foreground scan → album lookup → auto log play
- clear user feedback for unsupported/invalid tags

The NFC payload/association design should continue to keep the local database as the source of truth.
