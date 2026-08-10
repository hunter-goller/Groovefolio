$ErrorActionPreference = 'Stop'

Write-Host 'Formatting Dart files...'
dart format .

Write-Host 'Regenerating generated sources...'
dart run build_runner build

Write-Host 'Running analyzer...'
flutter analyze

Write-Host 'Running tests...'
flutter test

Write-Host 'Exporting Drift schema v1...'
New-Item -ItemType Directory -Force drift_schemas | Out-Null
dart run drift_dev schema dump lib/db/app_database.dart drift_schemas/

$schema = Join-Path 'drift_schemas' 'drift_schema_v1.json'
if (-not (Test-Path $schema)) {
  throw "Expected schema dump was not created at $schema"
}

# Parsing the file is an easy sanity check that the output is valid JSON.
Get-Content $schema -Raw | ConvertFrom-Json | Out-Null
Write-Host "VinylApp-012 verification passed. Valid schema dump: $schema"
