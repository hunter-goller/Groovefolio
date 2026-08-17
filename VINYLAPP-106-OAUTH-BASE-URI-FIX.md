# VinylApp-106 OAuth base-URI fix

Fixes Discogs OAuth HMAC-SHA1 signing.

`Uri.replace(query: '', fragment: '')` serialized the signature base URI with
empty query and fragment delimiters (`?#`). OAuth requires the base URI without
query or fragment components.

The deterministic OAuth signer tests should remain unchanged and now pass with:

`6T1I4Gr5ARlrRn7yR6rjMxMRBdo=`

After applying:

```powershell
.\tools\verify_vinylapp_012.ps1
.\tools\run_dev.ps1
```

Then retry Settings -> Connect Discogs.
