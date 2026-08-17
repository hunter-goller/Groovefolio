[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'

function Get-EnvironmentValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    # Prefer a value set for this PowerShell session, then fall back to the
    # persistent Windows user/machine environment variables.
    foreach ($target in @('Process', 'User', 'Machine')) {
        $value = [System.Environment]::GetEnvironmentVariable($Name, $target)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return $null
}

$consumerKey = Get-EnvironmentValue -Name 'DISCOGS_CONSUMER_KEY'
$consumerSecret = Get-EnvironmentValue -Name 'DISCOGS_CONSUMER_SECRET'

$missingVariables = @()
if ([string]::IsNullOrWhiteSpace($consumerKey)) {
    $missingVariables += 'DISCOGS_CONSUMER_KEY'
}
if ([string]::IsNullOrWhiteSpace($consumerSecret)) {
    $missingVariables += 'DISCOGS_CONSUMER_SECRET'
}

if ($missingVariables.Count -gt 0) {
    Write-Error @"
Missing required Discogs environment variable(s): $($missingVariables -join ', ')

Set them once for your Windows user, for example:

  [System.Environment]::SetEnvironmentVariable('DISCOGS_CONSUMER_KEY', '<your key>', 'User')
  [System.Environment]::SetEnvironmentVariable('DISCOGS_CONSUMER_SECRET', '<your secret>', 'User')

The values are read at runtime and are never written to the repository.
"@
    exit 1
}

$runArgs = @(
    'run'
    "--dart-define=DISCOGS_CONSUMER_KEY=$consumerKey"
    "--dart-define=DISCOGS_CONSUMER_SECRET=$consumerSecret"
)

if ($FlutterArgs) {
    $runArgs += $FlutterArgs
}

Write-Host 'Starting Groovefolio with Discogs developer credentials from Windows environment variables...'
& flutter @runArgs
exit $LASTEXITCODE
