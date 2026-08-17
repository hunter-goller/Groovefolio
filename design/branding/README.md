# Groovefolio branding

Current product name: **Groovefolio**.

VinylApp-067 establishes the first production launcher identity. The approved mark combines a vinyl record with a folio/record sleeve: the record is clearly visible above the folio opening, the mark stays predominantly black, and the orange accent is deliberately restrained.

## Approved v1 direction

- black/dark record + folio mark
- record visibly emerging from the folio opening
- subtle vinyl groove detail
- white record center label
- small Groovefolio orange accent on the folio edge
- horizontal wordmark is solid black with the dot over the `i` accented orange
- warm off-white launcher background
- monochrome fallback for Android 13+ themed icons

The app's broader UI accent remains `#D4622A`; the production icon assets normalize their orange accent to the same value.

## Assets

Production launcher sources in `assets/branding/`:

- `groovefolio_app_icon.png` — 1024×1024 legacy/master launcher image
- `groovefolio_adaptive_foreground.png` — transparent 1024×1024 adaptive foreground with safe-area padding
- `groovefolio_adaptive_monochrome.png` — transparent monochrome foreground for Android 13+ themed icons

Brand/reference assets in `design/branding/`:

- `groovefolio_app_icon_master.png` — 1024×1024 approved master
- `groovefolio_icon_mark.png` — transparent icon mark
- `groovefolio_wordmark.png` — horizontal icon + Groovefolio wordmark
- `groovefolio_brand_concept.png` — approved concept board/reference
- `groovefolio_launcher_mask_preview.png` — circle, squircle, and rounded-square preview

The approved concept originated as raster artwork, so this ticket does **not** pretend an auto-traced SVG is an authoritative vector master. A hand-cleaned vector source can be added later without changing the launcher configuration.

## Regenerating Android launcher resources

From the repository root:

```powershell
flutter pub get
dart run flutter_launcher_icons
```

The generator replaces the default Flutter launcher resources and creates the adaptive icon resources from `flutter_launcher_icons.yaml`.

Do not rename historical `VinylApp-###` tickets solely for branding; those IDs are project history.
