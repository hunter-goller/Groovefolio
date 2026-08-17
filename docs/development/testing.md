# Testing

Groovefolio has tests across database, migrations, repositories, providers, services, screens, routing, and shared widgets.

## Main command

```powershell
.\tools\verify_vinylapp_012.ps1
```

This is the preferred local source of truth because the repository treats analyzer infos as verification failures and also verifies generated sources/schema export.

## Direct Flutter tests

```powershell
flutter test
flutter test -r expanded test/services/stats_service_test.dart
```

## Current coverage areas
- Drift table/schema behavior
- v1→v2→v3 migration preservation
- album/artist/play/NFC/genre repositories
- provider overrides and collection providers
- play logging business rules
- stats aggregation/year filtering/yearly chart data
- artwork storage
- coordinated album deletion
- Add/Edit/Detail/Collection/Log Play screens
- genre/artwork/shared widgets
- OAuth signer behavior

## Filesystem-test note
A previous Windows Flutter widget test hung on `Directory.systemTemp.createTemp()`. ArtworkPicker tests avoid that pattern and inject deterministic rendering instead.
