# VinylApp-106 developer run helper

This small follow-up adds `tools/run_dev.ps1` for local Discogs development.

## One-time Windows setup

Store the Discogs developer credentials as persistent user environment variables:

```powershell
[System.Environment]::SetEnvironmentVariable(
    'DISCOGS_CONSUMER_KEY',
    'YOUR_ACTUAL_KEY',
    'User'
)

[System.Environment]::SetEnvironmentVariable(
    'DISCOGS_CONSUMER_SECRET',
    'YOUR_ACTUAL_SECRET',
    'User'
)
```

The helper reads the current PowerShell process first, then the Windows user and
machine environment-variable stores. You do not need to commit credentials or
put the literal values in a Flutter command.

## Normal development run

```powershell
.\tools\run_dev.ps1
```

Additional `flutter run` arguments can be appended, for example:

```powershell
.\tools\run_dev.ps1 -d <device-id>
```

The helper passes the stored values to Flutter as `--dart-define` values because
Groovefolio reads the Discogs consumer credentials with Dart compile-time
environment declarations.

The script never prints the credential values.
