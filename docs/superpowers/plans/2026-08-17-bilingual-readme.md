# Bilingual README Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stale README demo with a dated, fully bilingual explanation of expected execution time and the complete verified 2026-08-17 Dry Run output.

**Architecture:** Keep all user-facing project documentation in the root `README.md`. Present Chinese and English prose together, preserve the exact Chinese script output in one collapsed block, and place a faithful English rendering of the same immutable snapshot in a second collapsed block.

**Tech Stack:** Markdown, HTML `<details>` elements, PowerShell validation, Git.

## Global Constraints

- Document a common-path estimate of `2–4 seconds`, not an SLA.
- Record the approved snapshot exactly as 2026-08-17, Windows, PowerShell 7, Dry Run, 2.68 seconds, 37 public repositories, 103 received Stars, one GraphQL API call, and zero PUT attempts.
- Preserve all 37 repositories, their order, links, Stars, and states in both language blocks.
- State explicitly that the English block is a translation; the script itself still emits Chinese Markdown.
- Remove the stale 44-repository README claim and screenshot reference, but do not delete `assets/wan-ge-niu-bi-demo.jpg`.
- Do not modify `SKILL.md`, scripts, tests, or UI metadata.

---

### Task 1: Replace the README Introduction and Demo

**Files:**
- Modify: `README.md`
- Create: `docs/superpowers/plans/2026-08-17-bilingual-readme.md`
- Verify only: `assets/wan-ge-niu-bi-demo.jpg`

**Interfaces:**
- Consumes: the verified 2026-08-17 Dry Run Markdown and timing evidence from the approved design specification.
- Produces: a bilingual root README with a performance section, two complete output blocks, bilingual boundaries, and the existing `SKILL.md` link.

- [ ] **Step 1: Run the pre-change documentation contract and verify RED**

Run:

```powershell
$text = Get-Content -Raw -LiteralPath 'README.md'
$required = @(
    '## 执行耗时 / Execution Time',
    '常见路径通常预计在 **2–4 秒**内完成',
    'The common path is expected to complete in **2–4 seconds**',
    '<summary><strong>中文原始输出',
    '<summary><strong>English rendering of the same snapshot'
)
foreach ($item in $required) {
    if (-not $text.Contains($item)) { throw "README missing: $item" }
}
```

Expected: FAIL on `## 执行耗时 / Execution Time` because the current README has no performance or bilingual output sections.

- [ ] **Step 2: Write the minimal approved README**

Replace the current README body with these sections, in order:

1. `# 万哥牛逼 / Wan Ge Niu Bi`
2. paired Chinese and English introductions;
3. `## 执行耗时 / Execution Time` with the estimate, measured snapshot, and variability caveat;
4. `## 真实输出 / Real Output` with the dated environment facts;
5. a collapsed exact Chinese output containing all 37 rows;
6. a collapsed English rendering containing the same 37 rows and numbers;
7. `## 使用边界 / Boundaries` with each Chinese bullet immediately followed by its English translation;
8. the bilingual `SKILL.md` implementation-details link.

Keep the snapshot's summary values exactly:

```text
elapsed: 2.68 seconds
repositories: 37
verified starred: 37
received Stars: 103
GraphQL API calls: 1
PUT attempts: 0
```

- [ ] **Step 3: Re-run the documentation contract and verify GREEN**

Run the Step 1 command again.

Expected: PASS with no output.

- [ ] **Step 4: Verify snapshot parity and repository coverage**

Run:

```powershell
$text = Get-Content -Raw -LiteralPath 'README.md'
if (($text | Select-String -AllMatches 'https://github.com/' ).Matches.Count -ne 74) {
    throw 'Expected 37 repository links in each of two output blocks.'
}
foreach ($value in @('37/37', '103', '2.68', 'API 调用：1', 'API calls: 1')) {
    if (-not $text.Contains($value)) { throw "Snapshot value missing: $value" }
}
if ($text.Contains('复核了 44 个公开仓库')) {
    throw 'Stale 44-repository claim remains.'
}
if ($text.Contains('assets/wan-ge-niu-bi-demo.jpg')) {
    throw 'Stale screenshot remains referenced.'
}
```

Expected: PASS with 74 repository links and no stale text or screenshot reference.

- [ ] **Step 5: Run repository validation**

Run:

```powershell
python -X utf8 -B `
  'C:\Users\Daniel\.codex\skills\.system\skill-creator\scripts\quick_validate.py' `
  '.'
git diff --check
```

Expected: `Skill is valid!` and `git diff --check` exits 0.

- [ ] **Step 6: Review, commit, and push**

Stage only `README.md` and this implementation plan. Review the complete staged diff, then commit using the repository's Chinese subject style:

```powershell
git add -- README.md docs/superpowers/plans/2026-08-17-bilingual-readme.md
git commit -m '完善双语 README 与真实输出演示'
git push origin main
```

Expected: the new commit is present on `origin/main`; the previously committed design and ranking commits are pushed with it; the worktree is clean.
