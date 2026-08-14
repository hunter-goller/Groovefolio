$ErrorActionPreference = 'Stop'

function Assert-NativeSuccess([string]$Step) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Step failed with exit code $LASTEXITCODE"
  }
}

Write-Host 'Formatting Dart files...'
dart format .
Assert-NativeSuccess 'dart format'

Write-Host 'Regenerating generated sources...'
dart run build_runner build
Assert-NativeSuccess 'build_runner'

Write-Host 'Running analyzer...'
flutter analyze
Assert-NativeSuccess 'flutter analyze'

Write-Host 'Running tests...'
flutter test
Assert-NativeSuccess 'flutter test'

Write-Host 'Exporting current Drift schema...'
New-Item -ItemType Directory -Force drift_schemas | Out-Null
dart run drift_dev schema dump lib/db/app_database.dart drift_schemas/
Assert-NativeSuccess 'Drift schema dump'

$schema = Get-ChildItem drift_schemas -Filter 'drift_schema_v*.json' |
  Sort-Object {
    [int]($_.BaseName -replace '^drift_schema_v', '')
  } |
  Select-Object -Last 1

if ($null -eq $schema) {
  throw 'Expected a Drift schema dump but none was found.'
}

# Parsing the file is an easy sanity check that the output is valid JSON.
Get-Content $schema.FullName -Raw | ConvertFrom-Json | Out-Null
Write-Host "Verification passed. Valid current schema dump: $($schema.FullName)"
