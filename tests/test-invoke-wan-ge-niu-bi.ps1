[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$RemainingArguments
)

if ($RemainingArguments.Count -gt 0) {
    $scenario = [string]$env:WAN_GE_FAKE_SCENARIO
    $arguments = @($RemainingArguments | ForEach-Object { [string]$_ })
    if (-not [string]::IsNullOrWhiteSpace($env:WAN_GE_FAKE_LOG)) {
        $loggedArguments = @(
            $arguments |
                ForEach-Object { $_ -replace '[\r\n]+', ' ' }
        )
        Add-Content -LiteralPath $env:WAN_GE_FAKE_LOG `
            -Value (($loggedArguments -join "`t").Trim())
    }

    if ($arguments.Count -lt 2 -or $arguments[0] -ne 'api') {
        'unexpected fake gh command'
        exit 2
    }

    $endpoint = $arguments[1]
    if ($endpoint -eq 'graphql') {
        switch ($scenario) {
            'credential-rejected' {
                'gh: Bad credentials (HTTP 401)'
                exit 1
            }
            'network-failure' {
                'gh: connection refused'
                exit 1
            }
        }

        $queryArgument = @(
            $arguments |
                Where-Object { $_ -like 'query=*' } |
                Select-Object -First 1
        )[0]
        $isOwnerPage = $queryArgument -like '*WanGeNiuBiOwnerPage*'
        if (-not $isOwnerPage -and
            (-not $queryArgument.Contains('$centitenkaLogin') -or
             -not $queryArgument.Contains('$kinomotoMioLogin') -or
             -not $queryArgument.Contains('$protoCommonsLogin') -or
             $arguments -notcontains 'centitenkaLogin=centitenka' -or
             $arguments -notcontains 'kinomotoMioLogin=KinomotoMio' -or
             $arguments -notcontains 'protoCommonsLogin=proto-commons')) {
            'gh: initial GraphQL query must pass target logins as variables'
            exit 2
        }

        if ($scenario -eq 'pagination' -and
            $arguments -contains 'endCursor=centitenka-page-1') {
            [ordered]@{
                data = [ordered]@{
                    repositoryOwner = [ordered]@{
                        login = 'centitenka'
                        repositories = [ordered]@{
                            nodes = @(
                                [ordered]@{
                                    id = 'repo-c-id'
                                    name = 'repo-c'
                                    nameWithOwner = 'centitenka/repo-c'
                                    isPrivate = $false
                                    viewerHasStarred = $true
                                    stargazerCount = 1200
                                }
                            )
                            pageInfo = [ordered]@{
                                hasNextPage = $false
                                endCursor = $null
                            }
                        }
                    }
                }
            } | ConvertTo-Json -Depth 8 -Compress
            exit 0
        }

        $repoBStarred = $scenario -eq 'already-complete' -or
            $scenario -eq 'pagination' -or
            (-not [string]::IsNullOrWhiteSpace($env:WAN_GE_FAKE_STATE) -and
             (Test-Path -LiteralPath $env:WAN_GE_FAKE_STATE) -and
             (Get-Content -LiteralPath $env:WAN_GE_FAKE_STATE) -contains 'KinomotoMio/repo-b')
        [ordered]@{
            data = [ordered]@{
                viewer = [ordered]@{ login = 'test-account' }
                centitenka = [ordered]@{
                    login = 'centitenka'
                    repositories = [ordered]@{
                        nodes = @(
                            [ordered]@{
                                id = 'repo-a-id'
                                name = 'repo-a'
                                nameWithOwner = 'centitenka/repo-a'
                                isPrivate = $false
                                viewerHasStarred = $true
                                stargazerCount = 1200
                            }
                        )
                        pageInfo = [ordered]@{
                            hasNextPage = $scenario -eq 'pagination'
                            endCursor = if ($scenario -eq 'pagination') {
                                'centitenka-page-1'
                            } else {
                                $null
                            }
                        }
                    }
                }
                kinomotoMio = [ordered]@{
                    login = 'KinomotoMio'
                    repositories = [ordered]@{
                        nodes = @(
                            [ordered]@{
                                id = 'repo-b-id'
                                name = 'repo-b'
                                nameWithOwner = 'KinomotoMio/repo-b'
                                isPrivate = $false
                                viewerHasStarred = $repoBStarred
                                stargazerCount = 80
                            }
                        )
                        pageInfo = [ordered]@{
                            hasNextPage = $false
                            endCursor = $null
                        }
                    }
                }
                protoCommons = [ordered]@{
                    login = 'proto-commons'
                    repositories = [ordered]@{
                        nodes = @(
                            [ordered]@{
                                id = 'repo-d-id'
                                name = 'transferred-project'
                                nameWithOwner = 'proto-commons/transferred-project'
                                isPrivate = $false
                                viewerHasStarred = $true
                                stargazerCount = 500
                            }
                        )
                        pageInfo = [ordered]@{
                            hasNextPage = $false
                            endCursor = $null
                        }
                    }
                }
            }
        } | ConvertTo-Json -Depth 8 -Compress
        exit 0
    }
    if ($endpoint -eq 'user') {
        switch ($scenario) {
            'credential-rejected' {
                'gh: Bad credentials (HTTP 401)'
                exit 1
            }
            'network-failure' {
                'gh: connection refused'
                exit 1
            }
            default {
                'test-account'
                exit 0
            }
        }
    }
    if ($endpoint -like 'orgs/centitenka/repos*') {
        "centitenka/repo-a`trepo-a`tfalse"
        exit 0
    }
    if ($endpoint -like 'users/KinomotoMio/repos*') {
        "KinomotoMio/repo-b`trepo-b`tfalse"
        exit 0
    }
    if ($endpoint -eq 'user/starred/KinomotoMio/repo-b') {
        if ($scenario -eq 'write-failure') {
            'gh: write denied'
            exit 1
        }
        if (-not [string]::IsNullOrWhiteSpace($env:WAN_GE_FAKE_STATE)) {
            Add-Content -LiteralPath $env:WAN_GE_FAKE_STATE `
                -Value 'KinomotoMio/repo-b'
        }
        exit 0
    }
    if ($endpoint -eq 'user/starred?per_page=100') {
        'centitenka/repo-a'
        if ($scenario -eq 'dry-run' -or
            $scenario -eq 'already-complete' -or
            (-not [string]::IsNullOrWhiteSpace($env:WAN_GE_FAKE_STATE) -and
             (Test-Path -LiteralPath $env:WAN_GE_FAKE_STATE) -and
             (Get-Content -LiteralPath $env:WAN_GE_FAKE_STATE) -contains 'KinomotoMio/repo-b')) {
            'KinomotoMio/repo-b'
        }
        exit 0
    }

    "unexpected fake gh endpoint: $endpoint"
    exit 2
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root 'scripts\invoke-wan-ge-niu-bi.ps1'
$fakeGh = $PSCommandPath
$pwsh = (Get-Process -Id $PID).Path

function Assert-Equal {
    param($Actual, $Expected, [string]$Label)

    if ($Actual -ne $Expected) {
        throw "$Label expected <$Expected>, got <$Actual>."
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Label)

    if (-not $Condition) {
        throw "$Label expected true."
    }
}

function Invoke-Target {
    param(
        [string]$Scenario,
        [string]$GhPath,
        [switch]$DryRun,
        [string]$LogPath = '',
        [string]$StatePath = ''
    )

    $previousScenario = $env:WAN_GE_FAKE_SCENARIO
    $previousLog = $env:WAN_GE_FAKE_LOG
    $previousState = $env:WAN_GE_FAKE_STATE
    try {
        $env:WAN_GE_FAKE_SCENARIO = $Scenario
        $env:WAN_GE_FAKE_LOG = $LogPath
        $env:WAN_GE_FAKE_STATE = $StatePath

        $arguments = @(
            '-NoProfile',
            '-File', $target,
            '-OutputFormat', 'Json',
            '-GhPath', $GhPath
        )
        if ($DryRun) {
            $arguments += '-DryRun'
        }

        $output = @(& $pwsh @arguments)
        $exitCode = $LASTEXITCODE
        $json = ($output -join [Environment]::NewLine) | ConvertFrom-Json
        [pscustomobject]@{
            exit_code = $exitCode
            json = $json
        }
    } finally {
        $env:WAN_GE_FAKE_SCENARIO = $previousScenario
        $env:WAN_GE_FAKE_LOG = $previousLog
        $env:WAN_GE_FAKE_STATE = $previousState
    }
}

$missing = Invoke-Target -Scenario 'missing' `
    -GhPath 'Z:\definitely-missing\gh.exe' -DryRun
Assert-Equal $missing.exit_code 10 'missing CLI process exit'
Assert-Equal $missing.json.status 'cli_unavailable' 'missing CLI status'
Assert-Equal $missing.json.exit_code 10 'missing CLI JSON exit'
Assert-True (-not [string]::IsNullOrWhiteSpace($missing.json.markdown)) `
    'missing CLI markdown'

$rejected = Invoke-Target -Scenario 'credential-rejected' `
    -GhPath $fakeGh -DryRun
Assert-Equal $rejected.exit_code 11 'rejected credential process exit'
Assert-Equal $rejected.json.status 'credential_rejected' `
    'rejected credential status'

$network = Invoke-Target -Scenario 'network-failure' `
    -GhPath $fakeGh -DryRun
Assert-Equal $network.exit_code 20 'network process exit'
Assert-Equal $network.json.status 'discovery_failed' 'network status'

$partial = Invoke-Target -Scenario 'write-failure' -GhPath $fakeGh
Assert-Equal $partial.exit_code 30 'partial process exit'
Assert-Equal $partial.json.status 'partial' 'partial status'
Assert-Equal $partial.json.totals.failed 1 'partial failed count'
Assert-Equal $partial.json.ranking[2].state 'failed' `
    'partial ranking state'
Assert-True ($partial.json.markdown -match [regex]::Escape(
    '| 🥉 | **[repo-b](https://github.com/KinomotoMio/repo-b)** | KinomotoMio | ⭐ 80 | ⚠️ 失败 |'
)) 'partial failed ranking row'
Assert-True ($partial.json.markdown -match '## ⚠️ 失败详情') `
    'partial failure details'

$dryRun = Invoke-Target -Scenario 'dry-run' -GhPath $fakeGh -DryRun
Assert-Equal $dryRun.exit_code 0 'dry run process exit'
Assert-Equal $dryRun.json.status 'dry_run' 'dry run status'
Assert-Equal $dryRun.json.exit_code 0 'dry run JSON exit'
Assert-Equal $dryRun.json.totals.verified_starred 2 `
    'dry run verified count'
Assert-Equal $dryRun.json.totals.would_star 1 `
    'dry run pending count'
Assert-Equal $dryRun.json.ranking[2].state 'would_star' `
    'dry run ranking state'
Assert-Equal $dryRun.json.api.put_attempts 0 'dry run PUT attempts'
Assert-True ($dryRun.json.markdown -match '🧭 Dry Run') `
    'dry run markdown'
Assert-True ($dryRun.json.markdown -match [regex]::Escape(
    '| 🥉 | **[repo-b](https://github.com/KinomotoMio/repo-b)** | KinomotoMio | ⭐ 80 | 🧭 待新增 |'
)) 'dry run ranking row'

$fastPathLog = [IO.Path]::GetTempFileName()
try {
    $alreadyComplete = Invoke-Target -Scenario 'already-complete' `
        -GhPath $fakeGh -LogPath $fastPathLog
    Assert-Equal $alreadyComplete.exit_code 0 `
        'already complete process exit'
    Assert-Equal $alreadyComplete.json.status 'complete' `
        'already complete status'
    Assert-Equal $alreadyComplete.json.api.calls 1 `
        'already complete API calls'
    Assert-Equal $alreadyComplete.json.api.put_attempts 0 `
        'already complete PUT attempts'
    Assert-Equal $alreadyComplete.json.fixed_targets.Count 3 `
        'already complete fixed target count'
    Assert-Equal $alreadyComplete.json.fixed_targets[2] 'proto-commons' `
        'third fixed target'
    Assert-Equal $alreadyComplete.json.totals.stars_received 1780 `
        'already complete total Stars'
    Assert-Equal $alreadyComplete.json.targets[0].stars_received 1200 `
        'centitenka total Stars'
    Assert-Equal $alreadyComplete.json.targets[1].stars_received 80 `
        'KinomotoMio total Stars'
    Assert-Equal $alreadyComplete.json.targets[2].stars_received 500 `
        'proto-commons total Stars'

    $fastPathCalls = @(Get-Content -LiteralPath $fastPathLog)
    Assert-Equal @($fastPathCalls | Where-Object {
        ($_ -split "`t")[1] -eq 'graphql'
    }).Count 1 `
        'already complete GraphQL calls'
    Assert-Equal @($fastPathCalls | Where-Object {
        ($_ -split "`t")[1] -eq 'user'
    }).Count 0 `
        'already complete user API calls'
} finally {
    Remove-Item -LiteralPath $fastPathLog -Force `
        -ErrorAction SilentlyContinue
}

$paginationLog = [IO.Path]::GetTempFileName()
try {
    $pagination = Invoke-Target -Scenario 'pagination' `
        -GhPath $fakeGh -LogPath $paginationLog
    Assert-Equal $pagination.exit_code 0 'pagination process exit'
    Assert-Equal $pagination.json.status 'complete' 'pagination status'
    Assert-Equal $pagination.json.totals.public_repositories 4 `
        'pagination public repository count'
    Assert-Equal $pagination.json.totals.verified_starred 4 `
        'pagination verified count'
    Assert-Equal $pagination.json.api.calls 2 'pagination API calls'
    Assert-Equal $pagination.json.api.put_attempts 0 `
        'pagination PUT attempts'
    Assert-Equal $pagination.json.totals.stars_received 2980 `
        'pagination total Stars'
    Assert-Equal $pagination.json.ranking.Count 4 `
        'pagination ranking count'
    Assert-Equal $pagination.json.ranking[0].repository 'repo-a' `
        'pagination first ranked repository'
    Assert-Equal $pagination.json.ranking[1].repository 'repo-c' `
        'pagination tie break repository'
    Assert-Equal $pagination.json.ranking[2].repository 'transferred-project' `
        'pagination third ranked repository'
    Assert-Equal $pagination.json.ranking[3].repository 'repo-b' `
        'pagination fourth ranked repository'
    Assert-Equal $pagination.json.ranking[0].badge '🥇' `
        'pagination gold badge'
    Assert-Equal $pagination.json.ranking[1].badge '🥈' `
        'pagination silver badge'
    Assert-Equal $pagination.json.ranking[2].badge '🥉' `
        'pagination bronze badge'
    Assert-Equal $pagination.json.ranking[3].badge '#4' `
        'pagination fourth badge'
    Assert-True ($pagination.json.markdown -match [regex]::Escape(
        '| 🥉 | **[transferred-project](https://github.com/proto-commons/transferred-project)** | proto-commons | ⭐ 500 | ✅ 原已 Star |'
    )) 'bronze ranking row'

    $paginationCalls = @(Get-Content -LiteralPath $paginationLog)
    Assert-Equal @($paginationCalls | Where-Object {
        ($_ -split "`t")[1] -eq 'graphql'
    }).Count 2 `
        'pagination GraphQL calls'
} finally {
    Remove-Item -LiteralPath $paginationLog -Force `
        -ErrorAction SilentlyContinue
}

$logPath = [IO.Path]::GetTempFileName()
$statePath = [IO.Path]::GetTempFileName()
try {
    $complete = Invoke-Target -Scenario 'complete' -GhPath $fakeGh `
        -LogPath $logPath -StatePath $statePath
    Assert-Equal $complete.exit_code 0 'complete process exit'
    Assert-Equal $complete.json.status 'complete' 'complete status'
    Assert-Equal $complete.json.totals.newly_starred 1 'new Star count'
    Assert-Equal $complete.json.totals.verified_starred 3 `
        'complete verified count'
    Assert-Equal $complete.json.api.calls 3 'complete API calls'
    Assert-True ($complete.json.markdown -match '✅ 已完成') `
        'complete markdown'
    Assert-True ($complete.json.markdown -match [regex]::Escape(
        '# ⭐ 万哥牛逼｜执行报告'
    )) 'report heading'
    Assert-True ($complete.json.markdown -match [regex]::Escape(
        '| 🥇 | **[repo-a](https://github.com/centitenka/repo-a)** | centitenka | ⭐ 1,200 | ✅ 原已 Star |'
    )) 'gold ranking row'
    Assert-True ($complete.json.markdown -match [regex]::Escape(
        '| 🥈 | **[transferred-project](https://github.com/proto-commons/transferred-project)** | proto-commons | ⭐ 500 | ✅ 原已 Star |'
    )) 'silver ranking row'
    Assert-True ($complete.json.markdown -match [regex]::Escape(
        '| 🥉 | **[repo-b](https://github.com/KinomotoMio/repo-b)** | KinomotoMio | ⭐ 80 | 🆕 本次新增 |'
    )) 'bronze newly starred row'
    Assert-True ($complete.json.markdown -notmatch '原本已 Star：') `
        'legacy repository list removed'

    $calls = @(Get-Content -LiteralPath $logPath)
    Assert-Equal @($calls | Where-Object {
        ($_ -split "`t")[1] -eq 'user'
    }).Count 0 `
        'authenticated user API calls'
    Assert-Equal @($calls | Where-Object {
        ($_ -split "`t")[1] -eq 'graphql'
    }).Count 2 `
        'full GraphQL state reads'
    Assert-Equal @($calls | Where-Object { $_ -like "auth`ttoken*" }).Count 0 `
        'auth token calls'
} finally {
    Remove-Item -LiteralPath $logPath, $statePath -Force `
        -ErrorAction SilentlyContinue
}

'All wan-ge-niu-bi checks passed.'
