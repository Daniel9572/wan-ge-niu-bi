[CmdletBinding()]
param(
    [ValidateSet('Markdown', 'Json')]
    [string]$OutputFormat = 'Markdown',

    [switch]$DryRun,

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
        alias = 'centitenka'
    },
    [pscustomobject]@{
        owner = 'KinomotoMio'
        alias = 'kinomotoMio'
    },
    [pscustomobject]@{
        owner = 'proto-commons'
        alias = 'protoCommons'
    }
)

$initialStateQuery = @'
query WanGeNiuBiState(
  $centitenkaLogin: String!
  $kinomotoMioLogin: String!
  $protoCommonsLogin: String!
) {
  viewer { login }
  centitenka: repositoryOwner(login: $centitenkaLogin) {
    login
    repositories(
      first: 100
      privacy: PUBLIC
      ownerAffiliations: [OWNER]
      orderBy: { field: NAME, direction: ASC }
    ) {
      nodes { id name nameWithOwner isPrivate viewerHasStarred }
      pageInfo { hasNextPage endCursor }
    }
  }
  kinomotoMio: repositoryOwner(login: $kinomotoMioLogin) {
    login
    repositories(
      first: 100
      privacy: PUBLIC
      ownerAffiliations: [OWNER]
      orderBy: { field: NAME, direction: ASC }
    ) {
      nodes { id name nameWithOwner isPrivate viewerHasStarred }
      pageInfo { hasNextPage endCursor }
    }
  }
  protoCommons: repositoryOwner(login: $protoCommonsLogin) {
    login
    repositories(
      first: 100
      privacy: PUBLIC
      ownerAffiliations: [OWNER]
      orderBy: { field: NAME, direction: ASC }
    ) {
      nodes { id name nameWithOwner isPrivate viewerHasStarred }
      pageInfo { hasNextPage endCursor }
    }
  }
}
'@

$ownerPageQuery = @'
query WanGeNiuBiOwnerPage($login: String!, $endCursor: String) {
  repositoryOwner(login: $login) {
    login
    repositories(
      first: 100
      after: $endCursor
      privacy: PUBLIC
      ownerAffiliations: [OWNER]
      orderBy: { field: NAME, direction: ASC }
    ) {
      nodes { id name nameWithOwner isPrivate viewerHasStarred }
      pageInfo { hasNextPage endCursor }
    }
  }
}
'@

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
        [string[]]$Arguments
    )

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
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
        if ($attempt -lt $maxAttempts -and (Test-RetryableFailure $message)) {
            Start-Sleep -Seconds ([Math]::Pow(2, $attempt - 1))
            continue
        }

        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "GitHub CLI exited with code $exitCode."
        }
        throw [System.InvalidOperationException]::new($message)
    }
}

function Invoke-GraphQlQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [System.Collections.IDictionary]$Variables
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add('graphql')
    $arguments.Add('--hostname')
    $arguments.Add($hostname)
    if ($null -ne $Variables) {
        foreach ($key in $Variables.Keys) {
            $arguments.Add('-F')
            $arguments.Add("$key=$($Variables[$key])")
        }
    }
    $arguments.Add('-f')
    $arguments.Add("query=$Query")

    $lines = @(Invoke-GhApiLines -Arguments @($arguments))
    try {
        $response = ($lines -join [Environment]::NewLine) |
            ConvertFrom-Json
    } catch {
        throw [System.InvalidOperationException]::new(
            "GitHub GraphQL returned invalid JSON: $(Protect-Text $_.Exception.Message)"
        )
    }

    if ($response.PSObject.Properties.Name -contains 'errors' -and
        @($response.errors).Count -gt 0) {
        $messages = @(
            $response.errors |
                ForEach-Object { Protect-Text ([string]$_.message) }
        )
        throw [System.InvalidOperationException]::new(
            "GitHub GraphQL error: $($messages -join '; ')"
        )
    }
    if (-not ($response.PSObject.Properties.Name -contains 'data') -or
        $null -eq $response.data) {
        throw [System.InvalidOperationException]::new(
            'GitHub GraphQL returned no data.'
        )
    }

    return $response.data
}

function Add-RepositoryNodes {
    param(
        [Parameter(Mandatory = $true)][string]$Owner,
        [object[]]$Nodes,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$RepositoryLists,
        [System.Collections.Generic.HashSet[string]]$Seen,
        [System.Collections.Generic.HashSet[string]]$StarredSet
    )

    foreach ($node in @($Nodes)) {
        if ($null -eq $node -or [bool]$node.isPrivate) {
            continue
        }

        $fullName = [string]$node.nameWithOwner
        $expectedPrefix = "$Owner/"
        if ([string]::IsNullOrWhiteSpace($fullName) -or
            -not $fullName.StartsWith(
                $expectedPrefix,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            throw "Unexpected repository owner in GraphQL response: $fullName"
        }
        if (-not $Seen.Add($fullName)) {
            continue
        }

        $RepositoryLists[$Owner].Add([pscustomobject]@{
            owner = $Owner
            name = [string]$node.name
            full_name = $fullName
        })
        if ([bool]$node.viewerHasStarred) {
            [void]$StarredSet.Add($fullName)
        }
    }
}

function Get-GitHubState {
    $data = Invoke-GraphQlQuery -Query $initialStateQuery `
        -Variables ([ordered]@{
            centitenkaLogin = 'centitenka'
            kinomotoMioLogin = 'KinomotoMio'
            protoCommonsLogin = 'proto-commons'
        })
    $authenticatedLogin = [string]$data.viewer.login
    if ([string]::IsNullOrWhiteSpace($authenticatedLogin)) {
        throw 'GitHub GraphQL did not return the authenticated account.'
    }

    $repositoryLists = [ordered]@{}
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $starredSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($target in $targets) {
        $repositoryLists[$target.owner] =
            [System.Collections.Generic.List[object]]::new()
        $ownerNode = $data.($target.alias)
        if ($null -eq $ownerNode -or
            -not [string]::Equals(
                [string]$ownerNode.login,
                [string]$target.owner,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            throw "GitHub GraphQL did not return target $($target.owner)."
        }

        $connection = $ownerNode.repositories
        Add-RepositoryNodes -Owner $target.owner `
            -Nodes @($connection.nodes) -RepositoryLists $repositoryLists `
            -Seen $seen -StarredSet $starredSet

        $visitedCursors = [System.Collections.Generic.HashSet[string]]::new()
        while ([bool]$connection.pageInfo.hasNextPage) {
            $cursor = [string]$connection.pageInfo.endCursor
            if ([string]::IsNullOrWhiteSpace($cursor) -or
                -not $visitedCursors.Add($cursor)) {
                throw "Invalid GraphQL pagination cursor for $($target.owner)."
            }

            $pageData = Invoke-GraphQlQuery -Query $ownerPageQuery `
                -Variables ([ordered]@{
                    login = [string]$target.owner
                    endCursor = $cursor
                })
            $pageOwner = $pageData.repositoryOwner
            if ($null -eq $pageOwner -or
                -not [string]::Equals(
                    [string]$pageOwner.login,
                    [string]$target.owner,
                    [System.StringComparison]::OrdinalIgnoreCase
                )) {
                throw "GitHub GraphQL pagination lost target $($target.owner)."
            }

            $connection = $pageOwner.repositories
            Add-RepositoryNodes -Owner $target.owner `
                -Nodes @($connection.nodes) -RepositoryLists $repositoryLists `
                -Seen $seen -StarredSet $starredSet
        }
    }

    $discovery = [ordered]@{}
    foreach ($target in $targets) {
        $discovery[$target.owner] = @(
            $repositoryLists[$target.owner] |
                Sort-Object full_name
        )
    }

    return [pscustomobject]@{
        authenticated_login = $authenticatedLogin
        discovery = $discovery
        starred_set = $starredSet
    }
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

function Write-TerminalFailure {
    param(
        [string]$Status,
        [string]$Message,
        [int]$ExitCode
    )

    $markdown = "未执行：$Message`n未添加或移除任何 Star。"
    if ($OutputFormat -eq 'Json') {
        [ordered]@{
            schema_version = 1
            status = $Status
            exit_code = $ExitCode
            dry_run = [bool]$DryRun
            detail = $Message
            writes_attempted = 0
            markdown = $markdown
        } | ConvertTo-Json -Compress
    } else {
        $markdown
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
    $newlyStarred = @(
        $allRepositories |
            Where-Object {
                $StarredSet.Contains([string]$_.full_name) -and
                $AddedSet.Contains([string]$_.full_name)
            } |
            ForEach-Object { [string]$_.full_name } |
            Sort-Object
    )
    $wouldStar = @(
        $allRepositories |
            Where-Object {
                $IsDryRun -and -not $StarredSet.Contains([string]$_.full_name)
            } |
            ForEach-Object { [string]$_.full_name } |
            Sort-Object
    )
    $failed = [System.Collections.Generic.List[object]]::new()
    if (-not $IsDryRun) {
        foreach ($repository in $allRepositories) {
            $fullName = [string]$repository.full_name
            if ($StarredSet.Contains($fullName)) {
                continue
            }
            $detail = if ($FailureDetails.Contains($fullName)) {
                [string]$FailureDetails[$fullName]
            } else {
                'Final verification did not confirm this Star.'
            }
            $failed.Add([pscustomobject][ordered]@{
                repository = $fullName
                detail = Protect-Text $detail
            })
        }
    }

    $ownerSummaries = [System.Collections.Generic.List[object]]::new()
    foreach ($target in $targets) {
        $owned = @($Discovery[$target.owner])
        $verifiedCount = @(
            $owned |
                Where-Object { $StarredSet.Contains([string]$_.full_name) }
        ).Count
        $changeCount = if ($IsDryRun) {
            @(
                $owned |
                    Where-Object { -not $StarredSet.Contains([string]$_.full_name) }
            ).Count
        } else {
            @(
                $owned |
                    Where-Object {
                        $StarredSet.Contains([string]$_.full_name) -and
                        $AddedSet.Contains([string]$_.full_name)
                    }
            ).Count
        }
        $ownerFailed = if ($IsDryRun) { 0 } else { $owned.Count - $verifiedCount }
        $ownerSummaries.Add([pscustomobject][ordered]@{
            owner = [string]$target.owner
            public_repositories = $owned.Count
            verified_starred = $verifiedCount
            changed = $changeCount
            failed = $ownerFailed
        })
    }

    $verifiedTotal = @(
        $allRepositories |
            Where-Object { $StarredSet.Contains([string]$_.full_name) }
    ).Count

    return [pscustomobject][ordered]@{
        schema_version = 1
        status = $Status
        dry_run = $IsDryRun
        authenticated_account = $AuthenticatedLogin
        fixed_targets = @($targets | ForEach-Object { [string]$_.owner })
        totals = [pscustomobject][ordered]@{
            public_repositories = $allRepositories.Count
            verified_starred = $verifiedTotal
            newly_starred = $newlyStarred.Count
            already_starred = $verifiedTotal - $newlyStarred.Count
            would_star = $wouldStar.Count
            failed = $failed.Count
        }
        owners = @($ownerSummaries)
        newly_starred = $newlyStarred
        would_star = $wouldStar
        failed = @($failed)
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
    $heading = if ($Report.dry_run) {
        '🧭 Dry Run'
    } elseif ($Report.status -eq 'complete') {
        '✅ 已完成'
    } else {
        '⚠️ 部分完成'
    }
    $changeCount = if ($Report.dry_run) {
        $Report.totals.would_star
    } else {
        $Report.totals.newly_starred
    }
    $changeLabel = if ($Report.dry_run) { '待新增' } else { '新增' }

    $lines.Add('# ⭐ 万哥牛逼｜执行报告')
    $lines.Add('')
    $lines.Add(
        "> $heading · $($Report.totals.verified_starred)/" +
        "$($Report.totals.public_repositories) 已 Star · " +
        "$changeLabel $changeCount"
    )
    $lines.Add('>')
    $lines.Add(
        "> 执行账号：``$($Report.authenticated_account)`` · " +
        "API 调用：$($Report.api.calls)"
    )

    $ownerChangeHeader = if ($Report.dry_run) { '待新增' } else { '本次新增' }
    $lines.Add('')
    $lines.Add('## 作者概览')
    $lines.Add('')
    $lines.Add(
        "| 作者 | 公开仓库 | 已 Star | $ownerChangeHeader | 失败 |"
    )
    $lines.Add('| --- | ---: | ---: | ---: | ---: |')
    foreach ($owner in $Report.owners) {
        $lines.Add(
            "| $($owner.owner) | $($owner.public_repositories) | " +
            "$($owner.verified_starred) | $($owner.changed) | $($owner.failed) |"
        )
    }

    $changeItems = @(
        if ($Report.dry_run) {
            $Report.would_star
        } else {
            $Report.newly_starred
        }
    )
    if ($changeItems.Count -gt 0) {
        $lines.Add('')
        $changeHeading = if ($Report.dry_run) { '## 待新增' } else { '## 本次新增' }
        $lines.Add($changeHeading)
        $lines.Add('')
        foreach ($fullName in $changeItems) {
            $lines.Add("- ``$fullName``")
        }
    }

    if (@($Report.failed).Count -gt 0 -or
        @($Report.global_errors).Count -gt 0) {
        $lines.Add('')
        $lines.Add('## ⚠️ 失败详情')
        $lines.Add('')
        foreach ($failure in $Report.failed) {
            $lines.Add("- ``$($failure.repository)``：$($failure.detail)")
        }
        foreach ($globalError in @($Report.global_errors)) {
            $lines.Add("- 全局：$globalError")
        }
    }

    $lines.Add('')
    $lines.Add('私有仓库：按规则不查询、不操作。')
    return $lines -join [Environment]::NewLine
}

function Write-ReportOutput {
    param(
        [Parameter(Mandatory = $true)]$Report,
        [int]$ExitCode = 0
    )

    $markdown = Convert-ReportToMarkdown $Report
    if ($OutputFormat -eq 'Json') {
        $Report | Add-Member -NotePropertyName exit_code `
            -NotePropertyValue $ExitCode
        $Report | Add-Member -NotePropertyName markdown `
            -NotePropertyValue $markdown
        $Report | ConvertTo-Json -Depth 8 -Compress
    } else {
        $markdown
    }

    if ($ExitCode -ne 0) {
        exit $ExitCode
    }
}

if ([string]::IsNullOrWhiteSpace($GhPath)) {
    $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -ne $ghCommand) {
        $GhPath = $ghCommand.Source
    } else {
        $windowsCandidate = Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'
        if (Test-Path -LiteralPath $windowsCandidate -PathType Leaf) {
            $GhPath = $windowsCandidate
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GhPath) -or
    -not (Test-Path -LiteralPath $GhPath -PathType Leaf)) {
    Write-TerminalFailure -Status 'cli_unavailable' `
        -Message '未找到 GitHub CLI。' -ExitCode 10
}

$script:resolvedGhPath = (Resolve-Path -LiteralPath $GhPath).Path
$addedSet = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$failureDetails = [ordered]@{}

try {
    $initialState = Get-GitHubState
} catch {
    $message = Protect-Text $_.Exception.Message
    if ($message -match '(?i)HTTP\s+401\b|bad credentials|authentication failed|requires authentication') {
        Write-TerminalFailure -Status 'credential_rejected' `
            -Message 'GitHub 拒绝了当前凭据。' -ExitCode 11
    }
    if ($message -match '(?i)not logged (?:in|into)|gh auth login|authentication token is missing') {
        Write-TerminalFailure -Status 'credential_unavailable' `
            -Message '正常用户上下文中没有可用的 GitHub CLI 凭据。' -ExitCode 10
    }
    Write-TerminalFailure -Status 'discovery_failed' `
        -Message "实时仓库或 Star 状态发现失败：$message" -ExitCode 20
}

$authenticatedLogin = [string]$initialState.authenticated_login
$initialDiscovery = $initialState.discovery
$baselineStarred = $initialState.starred_set

if ($DryRun) {
    $report = New-Report -Status 'dry_run' -Discovery $initialDiscovery `
        -StarredSet $baselineStarred -AddedSet $addedSet `
        -FailureDetails $failureDetails -IsDryRun $true `
        -AuthenticatedLogin $authenticatedLogin
    Write-ReportOutput -Report $report
    return
}

$initialMissing = @(
    Get-AllRepositories -Discovery $initialDiscovery |
        Where-Object { -not $baselineStarred.Contains([string]$_.full_name) }
)
if ($initialMissing.Count -eq 0) {
    $report = New-Report -Status 'complete' -Discovery $initialDiscovery `
        -StarredSet $baselineStarred -AddedSet $addedSet `
        -FailureDetails $failureDetails -IsDryRun $false `
        -AuthenticatedLogin $authenticatedLogin
    Write-ReportOutput -Report $report
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
        foreach ($repository in $missing) {
            try {
                Invoke-StarRepository -Repository $repository
                [void]$addedSet.Add([string]$repository.full_name)
            } catch {
                $failureDetails[[string]$repository.full_name] =
                    Protect-Text $_.Exception.Message
            }
        }
    }

    try {
        $verifiedState = Get-GitHubState
        $finalDiscovery = $verifiedState.discovery
        $finalStarred = $verifiedState.starred_set
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
    -AuthenticatedLogin $authenticatedLogin `
    -GlobalErrors @($globalErrors)

$reportExitCode = if ($status -eq 'complete') { 0 } else { 30 }
Write-ReportOutput -Report $report -ExitCode $reportExitCode
