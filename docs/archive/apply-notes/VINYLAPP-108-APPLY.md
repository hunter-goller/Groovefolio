# VinylApp-108 apply notes

This changed-files overlay is based on the uploaded post-VinylApp-106-Part-1 `main` ZIP.

After extracting over the repository, remove the old typo/branding asset:

```powershell
git rm docs/vinyl_app_mopckup_dark.png
```

The replacement is:

```text
docs/groovefolio_mockup_dark.png
```

Then run:

```powershell
.\tools\verify_vinylapp_012.ps1
flutter build apk --debug
```

The product/repository name is Groovefolio, while `vinyl_app`, `VinylApp-###`, the Android application ID, database filename, and verifier script remain intentionally unchanged technical/historical identifiers.

Because Discogs OAuth has not shipped yet, this rename also changes the pre-release callback URI from `vinylapp://discogs-auth` to `groovefolio://discogs-auth` and updates the Discogs/dev-seed User-Agent branding.
