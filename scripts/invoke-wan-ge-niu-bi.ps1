[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:GH_NO_UPDATE_NOTIFIER = '1'
$env:GH_PROMPT_DISABLED = '1'
$env:GH_SPINNER_DISABLED = '1'

$apiVersion = '2026-03-10'
$hostname = 'github.com'
$targets = [ordered]@{
    centitenka = 'centitenka'
    KinomotoMio = 'kinomotoMio'
    'proto-commons' = 'protoCommons'
}

$initialQuery = @'
query WanGeNiuBiState(
  $centitenkaLogin: String!
  $kinomotoMioLogin: String!
  $protoCommonsLogin: String!
) {
  viewer { login }
  centitenka: repositoryOwner(login: $centitenkaLogin) {
    login
    repositories(first: 100, privacy: PUBLIC, ownerAffiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { name nameWithOwner viewerHasStarred stargazerCount }
      pageInfo { hasNextPage endCursor }
    }
  }
  kinomotoMio: repositoryOwner(login: $kinomotoMioLogin) {
    login
    repositories(first: 100, privacy: PUBLIC, ownerAffiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { name nameWithOwner viewerHasStarred stargazerCount }
      pageInfo { hasNextPage endCursor }
    }
  }
  protoCommons: repositoryOwner(login: $protoCommonsLogin) {
    login
    repositories(first: 100, privacy: PUBLIC, ownerAffiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { name nameWithOwner viewerHasStarred stargazerCount }
      pageInfo { hasNextPage endCursor }
    }
  }
}
'@

$pageQuery = @'
query WanGeNiuBiOwnerPage($login: String!, $endCursor: String) {
  repositoryOwner(login: $login) {
    login
    repositories(first: 100, after: $endCursor, privacy: PUBLIC, ownerAffiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { name nameWithOwner viewerHasStarred stargazerCount }
      pageInfo { hasNextPage endCursor }
    }
  }
}
'@

$script:ghPath = ''

function Protect-Text {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $text = [regex]::Replace(
        $Text,
        '(?i)\b(?:gh[pousr]_[A-Za-z0-9_]{8,}|github_pat_[A-Za-z0-9_]{8,})\b',
        '[REDACTED]'
    )
    return ([regex]::Replace($text, '[\r\n\t]+', ' ')).Trim()
}

function Test-RetryableFailure {
    param([string]$Message)
    return $Message -match '(?i)HTTP\s+(?:429|5\d\d)\b|secondary rate limit|rate limit exceeded|timed?\s*out|connection (?:reset|refused)|temporarily unavailable'
}

function Invoke-GhApi {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $output = @(& $script:ghPath api @Arguments 2>&1)
        if ($LASTEXITCODE -eq 0) {
            return @($output | ForEach-Object { [string]$_ })
        }

        $message = Protect-Text (($output | ForEach-Object { [string]$_ }) -join ' ')
        if ($attempt -lt 3 -and (Test-RetryableFailure $message)) {
            Start-Sleep -Seconds $attempt
            continue
        }
        if ([string]::IsNullOrWhiteSpace($message)) { $message = 'GitHub CLI 调用失败。' }
        throw $message
    }
}

function Invoke-GraphQl {
    param(
        [Parameter(Mandatory = $true)][string]$Query,
        [System.Collections.IDictionary]$Variables
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add('graphql')
    $arguments.Add('--hostname')
    $arguments.Add($hostname)
    foreach ($key in @($Variables.Keys)) {
        $arguments.Add('-F')
        $arguments.Add("$key=$($Variables[$key])")
    }
    $arguments.Add('-f')
    $arguments.Add("query=$Query")

    try {
        $response = (@(Invoke-GhApi -Arguments @($arguments)) -join [Environment]::NewLine) |
            ConvertFrom-Json
    } catch {
        throw "GitHub GraphQL 请求失败：$(Protect-Text $_.Exception.Message)"
    }

    if ($response.PSObject.Properties.Name -contains 'errors' -and @($response.errors).Count -gt 0) {
        $messages = @($response.errors | ForEach-Object { Protect-Text ([string]$_.message) })
        throw "GitHub GraphQL 错误：$($messages -join '; ')"
    }
    if (-not ($response.PSObject.Properties.Name -contains 'data') -or $null -eq $response.data) {
        throw 'GitHub GraphQL 未返回数据。'
    }
    return $response.data
}

function Add-Repositories {
    param(
        [string]$Owner,
        [object[]]$Nodes,
        [System.Collections.IDictionary]$Lists,
        [System.Collections.Generic.HashSet[string]]$Seen,
        [System.Collections.Generic.HashSet[string]]$Starred
    )

    foreach ($node in @($Nodes)) {
        if ($null -eq $node) { continue }
        $fullName = [string]$node.nameWithOwner
        if (-not $fullName.StartsWith("$Owner/", [StringComparison]::OrdinalIgnoreCase)) {
            throw "GitHub 返回了意外仓库：$fullName"
        }
        if (-not $Seen.Add($fullName)) { continue }
        $Lists[$Owner].Add([pscustomobject]@{
            owner = $Owner
            name = [string]$node.name
            full_name = $fullName
            stars = [long]$node.stargazerCount
        })
        if ([bool]$node.viewerHasStarred) { [void]$Starred.Add($fullName) }
    }
}

function Get-GitHubState {
    $data = Invoke-GraphQl -Query $initialQuery -Variables ([ordered]@{
        centitenkaLogin = 'centitenka'
        kinomotoMioLogin = 'KinomotoMio'
        protoCommonsLogin = 'proto-commons'
    })
    $account = [string]$data.viewer.login
    if ([string]::IsNullOrWhiteSpace($account)) { throw 'GitHub 未返回当前账号。' }

    $lists = [ordered]@{}
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $starred = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($owner in $targets.Keys) {
        $lists[$owner] = [System.Collections.Generic.List[object]]::new()
        $ownerNode = $data.($targets[$owner])
        if ($null -eq $ownerNode -or
            -not [string]::Equals([string]$ownerNode.login, $owner, [StringComparison]::OrdinalIgnoreCase)) {
            throw "GitHub 未返回目标 owner：$owner"
        }

        $connection = $ownerNode.repositories
        Add-Repositories -Owner $owner -Nodes @($connection.nodes) -Lists $lists -Seen $seen -Starred $starred
        $visited = [System.Collections.Generic.HashSet[string]]::new()
        while ([bool]$connection.pageInfo.hasNextPage) {
            $cursor = [string]$connection.pageInfo.endCursor
            if ([string]::IsNullOrWhiteSpace($cursor) -or -not $visited.Add($cursor)) {
                throw "GitHub 返回了无效分页游标：$owner"
            }
            $page = Invoke-GraphQl -Query $pageQuery -Variables ([ordered]@{
                login = $owner
                endCursor = $cursor
            })
            if ($null -eq $page.repositoryOwner -or
                -not [string]::Equals([string]$page.repositoryOwner.login, $owner, [StringComparison]::OrdinalIgnoreCase)) {
                throw "GitHub 分页丢失目标 owner：$owner"
            }
            $connection = $page.repositoryOwner.repositories
            Add-Repositories -Owner $owner -Nodes @($connection.nodes) -Lists $lists -Seen $seen -Starred $starred
        }
    }

    $repositories = [System.Collections.Generic.List[object]]::new()
    foreach ($owner in $targets.Keys) {
        foreach ($repository in @($lists[$owner])) {
            $repositories.Add($repository)
        }
    }
    $ranked = @(
        $repositories |
            Sort-Object `
                @{ Expression = { -[long]$_.stars } },
                @{ Expression = { ([string]$_.full_name).ToLowerInvariant() } },
                full_name
    )
    return [pscustomobject]@{
        account = $account
        repositories = $ranked
        starred = $starred
    }
}

function Invoke-Star {
    param([Parameter(Mandatory = $true)]$Repository)

    $owner = [Uri]::EscapeDataString([string]$Repository.owner)
    $name = [Uri]::EscapeDataString([string]$Repository.name)
    [void](Invoke-GhApi -Arguments @(
        "user/starred/$owner/$name",
        '--method', 'PUT',
        '--silent',
        '--header', 'Accept: application/vnd.github+json',
        '--header', "X-GitHub-Api-Version: $apiVersion"
    ))
}

function Write-Failure {
    param([string]$Message)
    "❌ 未执行：$(Protect-Text $Message)"
    exit 1
}

function Write-Report {
    param(
        [Parameter(Mandatory = $true)]$State,
        [System.Collections.Generic.HashSet[string]]$Added,
        [System.Collections.IDictionary]$FailureDetails
    )

    $missing = @($State.repositories | Where-Object { -not $State.starred.Contains([string]$_.full_name) })
    $confirmedAdded = @(
        $State.repositories |
            Where-Object {
                $State.starred.Contains([string]$_.full_name) -and
                $Added.Contains([string]$_.full_name)
            }
    )
    $starredCount = $State.repositories.Count - $missing.Count
    $lines = [System.Collections.Generic.List[string]]::new()
    if ($missing.Count -eq 0) {
        $lines.Add("✅ $starredCount/$($State.repositories.Count) 已 Star，本次新增 $($confirmedAdded.Count)")
    } else {
        $lines.Add("⚠️ $starredCount/$($State.repositories.Count) 已 Star，失败 $($missing.Count)")
    }
    $lines.Add("账号：``$($State.account)``")

    if ($confirmedAdded.Count -gt 0) {
        $lines.Add('')
        $lines.Add('本次新增：')
        foreach ($repository in $confirmedAdded) { $lines.Add("- ``$($repository.full_name)``") }
    }
    if ($missing.Count -gt 0) {
        $lines.Add('')
        $lines.Add('失败：')
        foreach ($repository in $missing) {
            $name = [string]$repository.full_name
            $detail = if ($FailureDetails.Contains($name)) {
                Protect-Text ([string]$FailureDetails[$name])
            } else {
                '最终核验未确认该 Star。'
            }
            $lines.Add("- ``$name``：$detail")
        }
    }

    $lines.Add('')
    $lines.Add('| # | 仓库 | Stars |')
    $lines.Add('| ---: | --- | ---: |')
    $rank = 0
    foreach ($repository in @($State.repositories)) {
        $rank++
        $fullName = [string]$repository.full_name
        $place = switch ($rank) { 1 { '🥇' } 2 { '🥈' } 3 { '🥉' } default { "#$rank" } }
        $project = "[$fullName](https://github.com/$fullName)"
        $lines.Add("| $place | $project | $($repository.stars) |")
    }
    $lines -join [Environment]::NewLine
}

$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($null -eq $gh) { Write-Failure '未找到 GitHub CLI。' }
$script:ghPath = $gh.Source

try {
    $initial = Get-GitHubState
} catch {
    Write-Failure $_.Exception.Message
}

$added = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$failures = [ordered]@{}
$missing = @($initial.repositories | Where-Object { -not $initial.starred.Contains([string]$_.full_name) })

if ($missing.Count -eq 0) {
    Write-Report -State $initial -Added $added -FailureDetails $failures
    return
}

foreach ($repository in $missing) {
    try {
        Invoke-Star $repository
        [void]$added.Add([string]$repository.full_name)
    } catch {
        $failures[[string]$repository.full_name] = Protect-Text $_.Exception.Message
    }
}

try {
    $final = Get-GitHubState
} catch {
    "⚠️ 部分完成：已尝试补齐 $($added.Count) 个 Star，但最终核验失败。"
    "账号：``$($initial.account)``"
    "错误：$(Protect-Text $_.Exception.Message)"
    exit 1
}

Write-Report -State $final -Added $added -FailureDetails $failures
$remaining = @($final.repositories | Where-Object { -not $final.starred.Contains([string]$_.full_name) })
if ($remaining.Count -gt 0) { exit 1 }
