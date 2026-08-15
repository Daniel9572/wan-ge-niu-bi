[CmdletBinding()]
param(
    [ValidateSet('Markdown', 'Json')]
    [string]$OutputFormat = 'Markdown',

    [switch]$DryRun,

    [ValidateRange(1, 100)]
    [int]$BatchSize = 20,

    [string]$GhPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:GH_NO_UPDATE_NOTIFIER = '1'
$env:GH_PROMPT_DISABLED = '1'
$env:GH_SPINNER_DISABLED = '1'

$apiVersion = '2026-03-10'
$hostname = 'github.com'
$targets = @(
    [pscustomobject]@{
        owner = 'centitenka'
        endpoint = 'orgs/centitenka/repos?type=public&per_page=100&sort=full_name&direction=asc'
    },
    [pscustomobject]@{
        owner = 'KinomotoMio'
        endpoint = 'users/KinomotoMio/repos?type=owner&per_page=100&sort=full_name&direction=asc'
    }
)

$script:resolvedGhPath = ''
$script:apiCallCount = 0
$script:putAttemptCount = 0

function Protect-Text {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return ''
    }

    $protected = [regex]::Replace(
        $Text,
        '(?i)\b(?:gh[pousr]_[A-Za-z0-9_]{8,}|github_pat_[A-Za-z0-9_]{8,})\b',
        '[REDACTED]'
    )
    $protected = [regex]::Replace(
        $protected,
        '(?i)(authorization\s*:\s*(?:bearer|token)\s+)\S+',
        '$1[REDACTED]'
    )
    return $protected.Trim()
}

function Test-RetryableFailure {
    param([string]$Message)

    return $Message -match '(?i)HTTP\s+(?:429|5\d\d)\b|secondary rate limit|rate limit exceeded|timed?\s*out|connection (?:reset|refused)|temporarily unavailable'
}

function Invoke-GhApiLines {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [ValidateRange(1, 5)]
        [int]$MaxAttempts = 3
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $script:apiCallCount++
        $output = @(& $script:resolvedGhPath api @Arguments 2>&1)
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            return @(
                $output |
                    ForEach-Object { [string]$_ } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
        }

        $message = Protect-Text (($output | ForEach-Object { [string]$_ }) -join ' ')
        if ($attempt -lt $MaxAttempts -and (Test-RetryableFailure $message)) {
            Start-Sleep -Seconds ([Math]::Pow(2, $attempt - 1))
            continue
        }

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "GitHub CLI exited with code $exitCode."
        }
        throw [System.InvalidOperationException]::new($message)
    }
}

function Get-TargetRepositories {
    $result = [ordered]@{}
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($target in $targets) {
        $lines = @(Invoke-GhApiLines -Arguments @(
            $target.endpoint,
            '--paginate',
            '--jq',
            '.[] | [.full_name, .name, .private, .fork, .archived] | @tsv',
            '--header',
            'Accept: application/vnd.github+json',
            '--header',
            "X-GitHub-Api-Version: $apiVersion"
        ))

        $repositories = [System.Collections.Generic.List[object]]::new()
        foreach ($line in $lines) {
            $parts = $line -split "`t", 5
            if ($parts.Count -ne 5) {
                throw "Unexpected repository row returned for $($target.owner)."
            }

            $fullName = [string]$parts[0]
            $expectedPrefix = "$($target.owner)/"
            if (-not $fullName.StartsWith(
                    $expectedPrefix,
                    [System.StringComparison]::OrdinalIgnoreCase
                )) {
                throw "Unexpected repository owner in API response: $fullName"
            }

            if ($parts[2] -ne 'false' -or -not $seen.Add($fullName)) {
                continue
            }

            $repositories.Add([pscustomobject]@{
                owner = [string]$target.owner
                name = [string]$parts[1]
                full_name = $fullName
                fork = $parts[3] -eq 'true'
                archived = $parts[4] -eq 'true'
            })
        }

        $result[$target.owner] = @($repositories | Sort-Object full_name)
    }

    return ,$result
}

function Get-AllRepositories {
    param([System.Collections.IDictionary]$Discovery)

    $repositories = [System.Collections.Generic.List[object]]::new()
    foreach ($target in $targets) {
        foreach ($repository in @($Discovery[$target.owner])) {
            $repositories.Add($repository)
        }
    }
    return @($repositories)
}

function Get-StarredSet {
    $lines = @(Invoke-GhApiLines -Arguments @(
        'user/starred?per_page=100',
        '--paginate',
        '--jq',
        '.[].full_name',
        '--header',
        'Accept: application/vnd.github+json',
        '--header',
        "X-GitHub-Api-Version: $apiVersion"
    ))

    $set = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($line in $lines) {
        [void]$set.Add([string]$line)
    }
    return ,$set
}

function Invoke-StarRepository {
    param([Parameter(Mandatory = $true)]$Repository)

    $encodedOwner = [Uri]::EscapeDataString([string]$Repository.owner)
    $encodedName = [Uri]::EscapeDataString([string]$Repository.name)
    $script:putAttemptCount++
    [void](Invoke-GhApiLines -Arguments @(
        "user/starred/$encodedOwner/$encodedName",
        '--method',
        'PUT',
        '--silent',
        '--header',
        'Accept: application/vnd.github+json',
        '--header',
        "X-GitHub-Api-Version: $apiVersion"
    ))
}

function Format-NameList {
    param([string[]]$Names)

    if ($null -eq $Names -or $Names.Count -eq 0) {
        return '无'
    }
    return (($Names | ForEach-Object { "``$_``" }) -join '、')
}

function Write-AuthFailure {
    param(
        [string]$Status,
        [string]$Message,
        [int]$ExitCode
    )

    if ($OutputFormat -eq 'Json') {
        [ordered]@{
            schema_version = 1
            status = $Status
            dry_run = [bool]$DryRun
            detail = $Message
            writes_attempted = 0
        } | ConvertTo-Json -Compress
    } else {
        "未执行：$Message`n未添加或移除任何 Star。"
    }
    exit $ExitCode
}

function New-Report {
    param(
        [string]$Status,
        [System.Collections.IDictionary]$Discovery,
        [System.Collections.Generic.HashSet[string]]$StarredSet,
        [System.Collections.Generic.HashSet[string]]$AddedSet,
        [System.Collections.IDictionary]$FailureDetails,
        [bool]$IsDryRun,
        [string]$AuthenticatedLogin,
        [string[]]$GlobalErrors = @()
    )

    $allRepositories = @(Get-AllRepositories -Discovery $Discovery)
    $targetReports = [System.Collections.Generic.List[object]]::new()
    $totalAdded = 0
    $totalExisting = 0
    $totalWouldAdd = 0
    $totalFailed = 0

    foreach ($target in $targets) {
        $owned = @($Discovery[$target.owner])
        $added = @(
            $owned |
                Where-Object {
                    $StarredSet.Contains([string]$_.full_name) -and
                    $AddedSet.Contains([string]$_.full_name)
                } |
                ForEach-Object { [string]$_.name } |
                Sort-Object
        )
        $wouldAdd = @(
            $owned |
                Where-Object {
                    $IsDryRun -and -not $StarredSet.Contains([string]$_.full_name)
                } |
                ForEach-Object { [string]$_.name } |
                Sort-Object
        )
        $existing = @(
            $owned |
                Where-Object {
                    $StarredSet.Contains([string]$_.full_name) -and
                    -not $AddedSet.Contains([string]$_.full_name)
                } |
                ForEach-Object { [string]$_.name } |
                Sort-Object
        )
        $failed = [System.Collections.Generic.List[object]]::new()
        foreach ($repository in $owned) {
            if (-not $StarredSet.Contains([string]$repository.full_name) -and -not $IsDryRun) {
                $detail = if ($FailureDetails.Contains([string]$repository.full_name)) {
                    [string]$FailureDetails[[string]$repository.full_name]
                } else {
                    'Final verification did not find this repository in the authenticated user Star list.'
                }
                $failed.Add([pscustomobject]@{
                    repository = [string]$repository.name
                    detail = Protect-Text $detail
                })
            }
        }

        $targetReports.Add([pscustomobject]@{
            owner = [string]$target.owner
            public_count = $owned.Count
            newly_starred = $added
            already_starred = $existing
            would_star = $wouldAdd
            failed = @($failed)
        })

        $totalAdded += $added.Count
        $totalExisting += $existing.Count
        $totalWouldAdd += $wouldAdd.Count
        $totalFailed += $failed.Count
    }

    return [pscustomobject][ordered]@{
        schema_version = 1
        status = $Status
        dry_run = $IsDryRun
        authenticated_account = $AuthenticatedLogin
        fixed_targets = @($targets | ForEach-Object { [string]$_.owner })
        totals = [pscustomobject][ordered]@{
            public_repositories = $allRepositories.Count
            newly_starred = $totalAdded
            already_starred = $totalExisting
            would_star = $totalWouldAdd
            failed = $totalFailed
            verified_starred = @(
                $allRepositories |
                    Where-Object { $StarredSet.Contains([string]$_.full_name) }
            ).Count
        }
        targets = @($targetReports)
        api = [pscustomobject][ordered]@{
            version = $apiVersion
            calls = $script:apiCallCount
            put_attempts = $script:putAttemptCount
        }
        global_errors = @($GlobalErrors | ForEach-Object { Protect-Text $_ })
        private_repositories = 'Not queried or modified.'
    }
}

function Convert-ReportToMarkdown {
    param([Parameter(Mandatory = $true)]$Report)

    $lines = [System.Collections.Generic.List[string]]::new()
    if ($Report.dry_run) {
        $lines.Add(
            "Dry Run 已完成：发现 $($Report.totals.public_repositories) 个公开仓库；" +
            "待新增 $($Report.totals.would_star) 个，原本已 Star $($Report.totals.already_starred) 个。"
        )
        $lines.Add('本次未发送任何 Star 写入请求。')
    } elseif ($Report.status -eq 'complete') {
        $lines.Add(
            "已完成并复核：两个目标下共 $($Report.totals.public_repositories) 个公开仓库全部显示为已 Star。"
        )
        $lines.Add(
            "本次新增 $($Report.totals.newly_starred) 个，原本已 Star $($Report.totals.already_starred) 个，失败 0 个。"
        )
    } else {
        $lines.Add(
            "部分完成：检查 $($Report.totals.public_repositories) 个公开仓库，" +
            "最终验证 $($Report.totals.verified_starred) 个已 Star，" +
            "仓库失败 $($Report.totals.failed) 个，全局错误 $($Report.global_errors.Count) 个。"
        )
    }

    $lines.Add("执行账号：``$($Report.authenticated_account)``")
    foreach ($targetReport in $Report.targets) {
        $owner = [string]$targetReport.owner
        $lines.Add('')
        $lines.Add("### [$owner](https://github.com/$owner)")
        $lines.Add('')
        $lines.Add("公开仓库：$($targetReport.public_count) 个")
        if ($Report.dry_run) {
            $lines.Add("待新增：$(Format-NameList @($targetReport.would_star))")
        } else {
            $lines.Add("本次新增：$(Format-NameList @($targetReport.newly_starred))")
        }
        $lines.Add("原本已 Star：$(Format-NameList @($targetReport.already_starred))")

        if ($targetReport.failed.Count -gt 0) {
            $lines.Add('失败：')
            foreach ($failure in $targetReport.failed) {
                $lines.Add("- ``$($failure.repository)``：$($failure.detail)")
            }
        } else {
            $lines.Add('失败：无')
        }
    }

    if ($Report.global_errors.Count -gt 0) {
        $lines.Add('')
        $lines.Add('全局错误：')
        foreach ($globalError in $Report.global_errors) {
            $lines.Add("- $globalError")
        }
    }

    $lines.Add('')
    $lines.Add('私有仓库：按规则不查询、不操作。')
    return $lines -join [Environment]::NewLine
}

$authScript = Join-Path $PSScriptRoot 'check-gh-auth.ps1'
if (-not (Test-Path -LiteralPath $authScript -PathType Leaf)) {
    Write-AuthFailure -Status 'cli_unavailable' `
        -Message '认证探针脚本不存在。' -ExitCode 10
}

try {
    $authRaw = & $authScript -Hostname $hostname -GhPath $GhPath
    $auth = ($authRaw -join [Environment]::NewLine) | ConvertFrom-Json
} catch {
    Write-AuthFailure -Status 'credential_unavailable' `
        -Message (Protect-Text $_.Exception.Message) -ExitCode 10
}

switch ([string]$auth.classification) {
    'auth_valid' {
        $script:resolvedGhPath = [string]$auth.gh_path
    }
    'credential_rejected' {
        Write-AuthFailure -Status 'credential_rejected' `
            -Message 'GitHub 能看到凭据，但拒绝了认证请求。' -ExitCode 11
    }
    default {
        Write-AuthFailure -Status 'credential_unavailable' `
            -Message '当前执行上下文无法使用 GitHub CLI 凭据；请在正常用户上下文复核。' `
            -ExitCode 10
    }
}

$addedSet = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$failureDetails = [ordered]@{}

try {
    $initialDiscovery = Get-TargetRepositories
    $baselineStarred = Get-StarredSet
} catch {
    $message = Protect-Text $_.Exception.Message
    if ($OutputFormat -eq 'Json') {
        [ordered]@{
            schema_version = 1
            status = 'discovery_failed'
            dry_run = [bool]$DryRun
            detail = $message
            writes_attempted = $script:putAttemptCount
        } | ConvertTo-Json -Compress
    } else {
        "未完成：实时仓库或 Star 状态发现失败。`n原因：$message`n未执行 Unstar。"
    }
    exit 20
}

if ($DryRun) {
    $report = New-Report -Status 'dry_run' -Discovery $initialDiscovery `
        -StarredSet $baselineStarred -AddedSet $addedSet `
        -FailureDetails $failureDetails -IsDryRun $true `
        -AuthenticatedLogin ([string]$auth.authenticated_login)
    if ($OutputFormat -eq 'Json') {
        $report | ConvertTo-Json -Depth 8 -Compress
    } else {
        Convert-ReportToMarkdown $report
    }
    return
}

$workingDiscovery = $initialDiscovery
$workingStarred = $baselineStarred
$finalDiscovery = $initialDiscovery
$finalStarred = $baselineStarred
$globalErrors = [System.Collections.Generic.List[string]]::new()
$verificationSucceeded = $false

for ($round = 1; $round -le 2; $round++) {
    $missing = @(
        Get-AllRepositories -Discovery $workingDiscovery |
            Where-Object { -not $workingStarred.Contains([string]$_.full_name) }
    )

    if ($missing.Count -gt 0) {
        for ($offset = 0; $offset -lt $missing.Count; $offset += $BatchSize) {
            $last = [Math]::Min($offset + $BatchSize - 1, $missing.Count - 1)
            $batch = @($missing[$offset..$last])
            $attempted = [System.Collections.Generic.List[object]]::new()

            foreach ($repository in $batch) {
                try {
                    Invoke-StarRepository -Repository $repository
                    [void]$addedSet.Add([string]$repository.full_name)
                    $attempted.Add($repository)
                } catch {
                    $failureDetails[[string]$repository.full_name] =
                        Protect-Text $_.Exception.Message
                }
            }

            if ($attempted.Count -eq 0) {
                continue
            }

            try {
                $batchStarred = Get-StarredSet
                $workingStarred = $batchStarred
                foreach ($repository in $attempted) {
                    if ($batchStarred.Contains([string]$repository.full_name)) {
                        [void]$failureDetails.Remove([string]$repository.full_name)
                    } else {
                        $failureDetails[[string]$repository.full_name] =
                            'PUT succeeded, but the batch verification did not find the Star.'
                    }
                }
            } catch {
                $verificationError = Protect-Text $_.Exception.Message
                foreach ($repository in $attempted) {
                    $failureDetails[[string]$repository.full_name] =
                        "Batch verification failed: $verificationError"
                }
            }
        }
    }

    try {
        $verifiedDiscovery = Get-TargetRepositories
        $verifiedStarred = Get-StarredSet
        $finalDiscovery = $verifiedDiscovery
        $finalStarred = $verifiedStarred
    } catch {
        $globalErrors.Add(
            "Full-scope verification failed: $(Protect-Text $_.Exception.Message)"
        )
        break
    }

    $finalRepositories = @(Get-AllRepositories -Discovery $finalDiscovery)
    foreach ($repository in $finalRepositories) {
        if ($finalStarred.Contains([string]$repository.full_name)) {
            [void]$failureDetails.Remove([string]$repository.full_name)
        }
    }

    $finalMissing = @(
        $finalRepositories |
            Where-Object { -not $finalStarred.Contains([string]$_.full_name) }
    )
    if ($finalMissing.Count -eq 0) {
        $verificationSucceeded = $true
        break
    }

    $workingDiscovery = $finalDiscovery
    $workingStarred = $finalStarred
}

$status = if ($verificationSucceeded) { 'complete' } else { 'partial' }

$report = New-Report -Status $status -Discovery $finalDiscovery `
    -StarredSet $finalStarred -AddedSet $addedSet `
    -FailureDetails $failureDetails -IsDryRun $false `
    -AuthenticatedLogin ([string]$auth.authenticated_login) `
    -GlobalErrors @($globalErrors)

if ($OutputFormat -eq 'Json') {
    $report | ConvertTo-Json -Depth 8 -Compress
} else {
    Convert-ReportToMarkdown $report
}

if ($status -ne 'complete') {
    exit 30
}
