[CmdletBinding()]
param(
    [string]$Hostname = 'github.com',
    [string]$GhPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Result {
    param(
        [string]$Classification,
        [string]$ResolvedGhPath,
        [bool]$EnvironmentTokenPresent,
        [bool]$TokenRetrievable,
        [bool]$ApiAuthenticated,
        [string]$AuthenticatedLogin,
        [string]$Detail
    )

    [ordered]@{
        classification            = $Classification
        hostname                  = $Hostname
        gh_path                   = $ResolvedGhPath
        environment_token_present = $EnvironmentTokenPresent
        token_retrievable         = $TokenRetrievable
        api_authenticated         = $ApiAuthenticated
        authenticated_login       = $AuthenticatedLogin
        detail                    = $Detail
    } | ConvertTo-Json -Compress
}

$environmentTokenPresent =
    -not [string]::IsNullOrEmpty($env:GH_TOKEN) -or
    -not [string]::IsNullOrEmpty($env:GITHUB_TOKEN)

if ([string]::IsNullOrWhiteSpace($GhPath)) {
    $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -ne $ghCommand) {
        $GhPath = $ghCommand.Source
    } else {
        $windowsCandidate = Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'
        if (Test-Path -LiteralPath $windowsCandidate) {
            $GhPath = $windowsCandidate
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GhPath) -or
    -not (Test-Path -LiteralPath $GhPath -PathType Leaf)) {
    Write-Result -Classification 'cli_unavailable' `
        -ResolvedGhPath '' `
        -EnvironmentTokenPresent $environmentTokenPresent `
        -TokenRetrievable $false `
        -ApiAuthenticated $false `
        -AuthenticatedLogin '' `
        -Detail 'GitHub CLI was not found.'
    exit 0
}

$GhPath = (Resolve-Path -LiteralPath $GhPath).Path

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $GhPath auth token --hostname $Hostname 1>$null 2>$null
    $tokenRetrievable = $LASTEXITCODE -eq 0

    $loginOutput = & $GhPath api user --hostname $Hostname --jq .login 2>$null
    $apiAuthenticated = $LASTEXITCODE -eq 0
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
$authenticatedLogin = if ($apiAuthenticated) {
    [string]($loginOutput | Select-Object -First 1)
} else {
    ''
}

if ($apiAuthenticated) {
    Write-Result -Classification 'auth_valid' `
        -ResolvedGhPath $GhPath `
        -EnvironmentTokenPresent $environmentTokenPresent `
        -TokenRetrievable $tokenRetrievable `
        -ApiAuthenticated $true `
        -AuthenticatedLogin $authenticatedLogin `
        -Detail 'GitHub accepted an authenticated API request.'
} elseif ($tokenRetrievable -or $environmentTokenPresent) {
    Write-Result -Classification 'credential_rejected' `
        -ResolvedGhPath $GhPath `
        -EnvironmentTokenPresent $environmentTokenPresent `
        -TokenRetrievable $tokenRetrievable `
        -ApiAuthenticated $false `
        -AuthenticatedLogin '' `
        -Detail 'A credential is available, but GitHub did not accept the API request.'
} else {
    Write-Result -Classification 'credential_unavailable' `
        -ResolvedGhPath $GhPath `
        -EnvironmentTokenPresent $false `
        -TokenRetrievable $false `
        -ApiAuthenticated $false `
        -AuthenticatedLogin '' `
        -Detail 'No credential is visible to the current process. Retry in the normal user context before diagnosing token expiry.'
}
