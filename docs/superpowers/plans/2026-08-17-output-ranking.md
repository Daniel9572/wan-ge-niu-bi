# Wan Ge Niu Bi Output Ranking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add current GitHub Stars and a deterministic, polished global repository ranking to the script-generated JSON and Markdown report without increasing the common-path API call count.

**Architecture:** Extend the existing GraphQL repository nodes with `stargazerCount`, preserve that value as `star_count`, and have `New-Report` build one complete ranking shared by JSON and Markdown. Keep all sorting, badges, numeric formatting, and status labels inside PowerShell so the model still returns the script's `markdown` verbatim.

**Tech Stack:** PowerShell 7, Windows PowerShell 5.1, GitHub CLI GraphQL API, JSON, Markdown.

## Global Constraints

- Fixed targets remain exactly `centitenka` and `KinomotoMio`.
- Query only public repositories, including forks and archived repositories.
- Never add an Unstar path; existing PUT and final verification behavior remains intact.
- The common path remains one GraphQL call; cursor pagination remains mandatory above 100 repositories per owner.
- Sort by `star_count` descending, then `full_name` case-insensitively ascending.
- Show every repository; emphasize only the global top three with `🥇`, `🥈`, and `🥉`.
- Generate JSON and Markdown deterministically in the script; do not move presentation decisions into SKILL.md or the model.
- Preserve UTF-8 BOM compatibility for both executable PowerShell files.
- Do not create a Git commit or push unless the user explicitly authorizes it.

Reference design: `docs/superpowers/specs/2026-08-17-output-ranking-design.md`.

---

### Task 1: Collect Star Counts and Build the Structured Ranking

**Files:**
- Modify: `tests/test-invoke-wan-ge-niu-bi.ps1:52-130,275-320`
- Modify: `scripts/invoke-wan-ge-niu-bi.ps1:31-77,197-306,379-482`

**Interfaces:**
- Consumes: GitHub GraphQL `Repository.stargazerCount`, existing `Discovery`, `StarredSet`, `AddedSet`, and `FailureDetails`.
- Produces: repository property `star_count`; `totals.stars_received`; `targets[].stars_received`; complete `ranking[]` rows with `rank`, `badge`, `owner`, `repository`, `full_name`, `url`, `star_count`, and `state`.

- [ ] **Step 1: Add literal Star fixtures and ranking assertions**

Add `stargazerCount` to every fake GraphQL repository node:

```powershell
# repo-a and paginated repo-c intentionally tie to test the full_name tie-break.
stargazerCount = 1200 # centitenka/repo-a
stargazerCount = 80   # KinomotoMio/repo-b
stargazerCount = 1200 # centitenka/repo-c
```

Change the fake Dry Run so `repo-b` is not initially starred by removing `dry-run` from `$repoBStarred`. Add these assertions:

```powershell
Assert-Equal $dryRun.json.totals.verified_starred 1 `
    'dry run verified count'
Assert-Equal $dryRun.json.totals.would_star 1 'dry run would Star count'
Assert-Equal $dryRun.json.ranking[1].state 'would_star' `
    'dry run ranking state'

Assert-Equal $alreadyComplete.json.totals.stars_received 1280 `
    'already complete received Stars'
Assert-Equal $alreadyComplete.json.targets[0].stars_received 1200 `
    'centitenka received Stars'
Assert-Equal $alreadyComplete.json.targets[1].stars_received 80 `
    'KinomotoMio received Stars'

Assert-Equal $pagination.json.totals.stars_received 2480 `
    'pagination received Stars'
Assert-Equal $pagination.json.ranking.Count 3 'pagination ranking count'
Assert-Equal $pagination.json.ranking[0].full_name `
    'centitenka/repo-a' 'ranking first tie-break'
Assert-Equal $pagination.json.ranking[1].full_name `
    'centitenka/repo-c' 'ranking second tie-break'
Assert-Equal $pagination.json.ranking[2].full_name `
    'KinomotoMio/repo-b' 'ranking third repository'
Assert-Equal $pagination.json.ranking[0].badge '🥇' `
    'ranking gold badge'
Assert-Equal $pagination.json.ranking[1].badge '🥈' `
    'ranking silver badge'
Assert-Equal $pagination.json.ranking[2].badge '🥉' `
    'ranking bronze badge'
```

- [ ] **Step 2: Run the PowerShell 7 test and verify RED**

Run:

```powershell
& (Get-Process -Id $PID).Path -NoProfile `
  -File '.\tests\test-invoke-wan-ge-niu-bi.ps1'
```

Expected: FAIL because `stargazerCount`, `stars_received`, and `ranking` are not yet produced.

- [ ] **Step 3: Extend both GraphQL queries and repository objects**

Change both repository node selections to:

```graphql
nodes {
  id
  name
  nameWithOwner
  isPrivate
  viewerHasStarred
  stargazerCount
}
```

Extend the object created by `Add-RepositoryNodes`:

```powershell
$RepositoryLists[$Owner].Add([pscustomobject]@{
    owner = $Owner
    name = [string]$node.name
    full_name = $fullName
    star_count = [int64]$node.stargazerCount
})
```

- [ ] **Step 4: Build target totals and global ranking in `New-Report`**

For each target, calculate Stars from `$owned` and add the field to the target report:

```powershell
$targetStarsReceived = [int64](
    ($owned | Measure-Object -Property star_count -Sum).Sum
)

$targetReports.Add([pscustomobject]@{
    owner = [string]$target.owner
    public_count = $owned.Count
    stars_received = $targetStarsReceived
    newly_starred = $added
    already_starred = $existing
    would_star = $wouldAdd
    failed = @($failed)
})
```

Build the ranking after all target reports are available:

```powershell
$sortedRepositories = @(
    $allRepositories |
        Sort-Object `
            @{ Expression = { [int64]$_.star_count }; Descending = $true }, `
            @{ Expression = { ([string]$_.full_name).ToUpperInvariant() }; Descending = $false }
)
$ranking = [System.Collections.Generic.List[object]]::new()

for ($index = 0; $index -lt $sortedRepositories.Count; $index++) {
    $repository = $sortedRepositories[$index]
    $rank = $index + 1
    $isStarred = $StarredSet.Contains([string]$repository.full_name)
    $state = if ($FailureDetails.Contains([string]$repository.full_name)) {
        'failed'
    } elseif ($IsDryRun -and -not $isStarred) {
        'would_star'
    } elseif (-not $isStarred) {
        'failed'
    } elseif ($AddedSet.Contains([string]$repository.full_name)) {
        'newly_starred'
    } else {
        'already_starred'
    }
    $badge = switch ($rank) {
        1 { '🥇' }
        2 { '🥈' }
        3 { '🥉' }
        default { "#$rank" }
    }

    $ranking.Add([pscustomobject][ordered]@{
        rank = $rank
        badge = $badge
        owner = [string]$repository.owner
        repository = [string]$repository.name
        full_name = [string]$repository.full_name
        url = "https://github.com/$($repository.full_name)"
        star_count = [int64]$repository.star_count
        state = $state
    })
}
```

Add the aggregate fields to the final report:

```powershell
stars_received = [int64](
    ($allRepositories | Measure-Object -Property star_count -Sum).Sum
)
ranking = @($ranking)
```

- [ ] **Step 5: Run the PowerShell 7 test and verify GREEN**

Run the same test command from Step 2.

Expected: `All wan-ge-niu-bi checks passed.`

- [ ] **Step 6: Review the Task 1 diff and optionally commit**

Run:

```powershell
git diff --check
git diff -- scripts/invoke-wan-ge-niu-bi.ps1 tests/test-invoke-wan-ge-niu-bi.ps1
```

If and only if the user explicitly authorizes commits:

```powershell
git add scripts/invoke-wan-ge-niu-bi.ps1 tests/test-invoke-wan-ge-niu-bi.ps1
git commit -m "feat: add repository Star ranking"
```

---

### Task 2: Render the Polished Markdown Report

**Files:**
- Modify: `tests/test-invoke-wan-ge-niu-bi.ps1:250-360`
- Modify: `scripts/invoke-wan-ge-niu-bi.ps1:484-540`

**Interfaces:**
- Consumes: `Report.ranking`, `Report.totals.stars_received`, `Report.targets[].stars_received`, existing status totals, API calls, account, and failure lists.
- Produces: deterministic Markdown with one summary block, one complete global ranking table, one owner overview table, conditional failure details, and the private-repository boundary.

- [ ] **Step 1: Add exact Markdown assertions**

Add assertions for the normal completed report:

```powershell
Assert-True ($complete.json.markdown -match [regex]::Escape(
    '# ⭐ 万哥牛逼｜执行报告'
)) 'report heading'
Assert-True ($complete.json.markdown -match [regex]::Escape(
    '| 🥇 | **[repo-a](https://github.com/centitenka/repo-a)** | centitenka | ⭐ 1,200 | ✅ 原已 Star |'
)) 'gold ranking row'
Assert-True ($complete.json.markdown -match [regex]::Escape(
    '| 🥈 | **[repo-b](https://github.com/KinomotoMio/repo-b)** | KinomotoMio | ⭐ 80 | 🆕 本次新增 |'
)) 'silver ranking row'
Assert-True ($complete.json.markdown -notmatch '原本已 Star：') `
    'legacy repository list removed'
```

Add a Dry Run assertion:

```powershell
Assert-True ($dryRun.json.markdown -match [regex]::Escape(
    '| 🥈 | **[repo-b](https://github.com/KinomotoMio/repo-b)** | KinomotoMio | ⭐ 80 | 🧭 待新增 |'
)) 'dry run ranking row'
```

Add pagination assertions for the bronze row and stable tied order:

```powershell
Assert-True ($pagination.json.markdown -match [regex]::Escape(
    '| 🥉 | **[repo-b](https://github.com/KinomotoMio/repo-b)** | KinomotoMio | ⭐ 80 | ✅ 原已 Star |'
)) 'bronze ranking row'
```

- [ ] **Step 2: Run the PowerShell 7 test and verify RED**

Run:

```powershell
& (Get-Process -Id $PID).Path -NoProfile `
  -File '.\tests\test-invoke-wan-ge-niu-bi.ps1'
```

Expected: FAIL because the legacy per-owner name lists are still rendered.

- [ ] **Step 3: Add deterministic formatting helpers**

Add these helpers before `Convert-ReportToMarkdown`:

```powershell
function Format-Integer {
    param([int64]$Value)

    return [string]::Format(
        [System.Globalization.CultureInfo]::InvariantCulture,
        '{0:N0}',
        $Value
    )
}

function Get-RankingStateLabel {
    param([string]$State)

    switch ($State) {
        'newly_starred' { return '🆕 本次新增' }
        'would_star' { return '🧭 待新增' }
        'failed' { return '⚠️ 失败' }
        default { return '✅ 原已 Star' }
    }
}
```

- [ ] **Step 4: Replace `Convert-ReportToMarkdown` with the approved layout**

Build the summary deterministically:

```powershell
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
    "$changeLabel $changeCount · ⭐ 项目累计 Stars " +
    (Format-Integer ([int64]$Report.totals.stars_received))
)
$lines.Add('>')
$lines.Add(
    "> 执行账号：``$($Report.authenticated_account)`` · " +
    "API 调用：$($Report.api.calls)"
)
```

Render all ranking rows once:

```powershell
$lines.Add('')
$lines.Add('## 项目总榜')
$lines.Add('')
$lines.Add('| 排名 | 项目 | 作者 | 当前 Stars | 状态 |')
$lines.Add('| ---: | --- | --- | ---: | --- |')
foreach ($row in @($Report.ranking)) {
    $project = "[$($row.repository)]($($row.url))"
    if ([int]$row.rank -le 3) {
        $project = "**$project**"
    }
    $lines.Add(
        "| $($row.badge) | $project | $($row.owner) | " +
        "⭐ $(Format-Integer ([int64]$row.star_count)) | " +
        "$(Get-RankingStateLabel ([string]$row.state)) |"
    )
}
```

Render the owner overview with a dynamic Dry Run change header:

```powershell
$ownerChangeHeader = if ($Report.dry_run) { '待新增' } else { '本次新增' }
$lines.Add('')
$lines.Add('## 作者概览')
$lines.Add('')
$lines.Add(
    "| 作者 | 公开仓库 | 项目累计 Stars | $ownerChangeHeader | 失败 |"
)
$lines.Add('| --- | ---: | ---: | ---: | ---: |')
foreach ($targetReport in @($Report.targets)) {
    $ownerChangeCount = if ($Report.dry_run) {
        $targetReport.would_star.Count
    } else {
        $targetReport.newly_starred.Count
    }
    $lines.Add(
        "| $($targetReport.owner) | $($targetReport.public_count) | " +
        "$(Format-Integer ([int64]$targetReport.stars_received)) | " +
        "$ownerChangeCount | $($targetReport.failed.Count) |"
    )
}
```

Preserve repository and global failure details only when present:

```powershell
$repositoryFailures = @(
    $Report.targets |
        ForEach-Object { @($_.failed) }
)
if ($repositoryFailures.Count -gt 0 -or $Report.global_errors.Count -gt 0) {
    $lines.Add('')
    $lines.Add('## ⚠️ 失败详情')
    $lines.Add('')
    foreach ($failure in $repositoryFailures) {
        $lines.Add("- ``$($failure.repository)``：$($failure.detail)")
    }
    foreach ($globalError in @($Report.global_errors)) {
        $lines.Add("- 全局：$globalError")
    }
}
```

Then finish with:

```powershell
$lines.Add('')
$lines.Add('私有仓库：按规则不查询、不操作。')
return $lines -join [Environment]::NewLine
```

- [ ] **Step 5: Run the PowerShell 7 test and verify GREEN**

Run the same test command from Step 2.

Expected: `All wan-ge-niu-bi checks passed.`

- [ ] **Step 6: Review the Task 2 diff and optionally commit**

Run:

```powershell
git diff --check
git diff -- scripts/invoke-wan-ge-niu-bi.ps1 tests/test-invoke-wan-ge-niu-bi.ps1
```

If and only if the user explicitly authorizes commits:

```powershell
git add scripts/invoke-wan-ge-niu-bi.ps1 tests/test-invoke-wan-ge-niu-bi.ps1
git commit -m "feat: polish wan-ge-niu-bi report"
```

---

### Task 3: Cross-Runtime and Live Verification

**Files:**
- Verify: `scripts/invoke-wan-ge-niu-bi.ps1`
- Verify: `tests/test-invoke-wan-ge-niu-bi.ps1`
- Verify: `SKILL.md`
- Verify: `agents/openai.yaml`

**Interfaces:**
- Consumes: completed script and tests from Tasks 1-2.
- Produces: fresh evidence for PowerShell 7, Windows PowerShell 5.1, Skill validity, BOM preservation, one-call live GraphQL behavior, output appearance, and worktree boundaries.

- [ ] **Step 1: Run the full offline suite under both PowerShell runtimes**

```powershell
& (Get-Process -Id $PID).Path -NoProfile `
  -File '.\tests\test-invoke-wan-ge-niu-bi.ps1'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& 'C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe' `
  -NoProfile -ExecutionPolicy Bypass `
  -File '.\tests\test-invoke-wan-ge-niu-bi.ps1'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

Expected: both runs print `All wan-ge-niu-bi checks passed.`

- [ ] **Step 2: Validate the Skill, BOM, syntax, and diff**

```powershell
python -X utf8 -B `
  'C:\Users\Daniel\.codex\skills\.system\skill-creator\scripts\quick_validate.py' `
  '.'

$null = [ScriptBlock]::Create(
    (Get-Content -Raw -LiteralPath '.\scripts\invoke-wan-ge-niu-bi.ps1')
)

$paths = @(
    '.\scripts\invoke-wan-ge-niu-bi.ps1',
    '.\tests\test-invoke-wan-ge-niu-bi.ps1'
)
foreach ($path in $paths) {
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $path))
    if (-not ($bytes[0] -eq 0xEF -and
              $bytes[1] -eq 0xBB -and
              $bytes[2] -eq 0xBF)) {
        throw "$path is missing its UTF-8 BOM."
    }
}

git diff --check
```

Expected: `Skill is valid!`, no syntax exception, both BOM checks pass, and `git diff --check` exits 0.

- [ ] **Step 3: Run one real read-only Dry Run and measure it**

Request normal-user approval and state that this diagnostic queries only the two fixed targets' public repositories and performs no Star writes. Run:

```powershell
$timer = [Diagnostics.Stopwatch]::StartNew()
$raw = @(
    & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile `
      -File '.\scripts\invoke-wan-ge-niu-bi.ps1' `
      -DryRun -OutputFormat Json
)
$code = $LASTEXITCODE
$timer.Stop()
$report = ($raw -join [Environment]::NewLine) | ConvertFrom-Json

if ($code -ne 0) { exit $code }
if ($report.status -ne 'dry_run') { throw 'Unexpected live status.' }
if ($report.api.calls -ne 1) { throw 'Common path used more than one API call.' }
if ($report.api.put_attempts -ne 0) { throw 'Dry Run attempted a PUT.' }
if ($report.ranking.Count -ne $report.totals.public_repositories) {
    throw 'Ranking does not contain every public repository.'
}

"elapsed_ms=$([Math]::Round($timer.Elapsed.TotalMilliseconds, 1))"
$report.markdown
```

Expected: one API call, zero PUT attempts, ranking count equal to public repository count, and the polished Markdown displays all projects in descending Star order.

- [ ] **Step 4: Inspect the final worktree without staging**

```powershell
git status --short --branch
git diff --stat
git diff --check
```

Expected: only the previously approved Skill cleanup, ranking implementation, tests, spec, and plan remain uncommitted; nothing is staged or pushed.
