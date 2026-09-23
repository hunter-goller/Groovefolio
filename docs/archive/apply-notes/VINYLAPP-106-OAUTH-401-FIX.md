# VinylApp-106 OAuth 401 correction

Apply this overlay after the VinylApp-106 Part 2 overlay.

Changes:
- Sends `oauth_callback` as an `application/x-www-form-urlencoded` request-token body parameter, matching Discogs' OAuth request-token flow.
- Includes form body parameters in the HMAC-SHA1 signature base string.
- Keeps OAuth protocol fields in the Authorization header without duplicating the callback.
- Surfaces Discogs' response `message` for non-success responses while redacting the configured consumer key/secret.
- Adds deterministic signing coverage for the body-parameter path.

Then run:

```powershell
flutter pub get
.\tools\verify_vinylapp_012.ps1
.\tools\run_dev.ps1
```

Try Settings -> Connect Discogs again. If Discogs still returns a 401, send the new on-screen error text; it should now include Discogs' reason without exposing the configured key/secret.
