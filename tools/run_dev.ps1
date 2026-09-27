[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)
$ErrorActionPreference = 'Stop'
# The default build uses https://api.groovefolio.app. No consumer secrets belong in the app.
& flutter run @FlutterArgs
exit $LASTEXITCODE
