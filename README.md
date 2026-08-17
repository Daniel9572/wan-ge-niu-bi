# 万哥牛逼 / Wan Ge Niu Bi

一个仅在用户显式调用 `$wan-ge-niu-bi` 时运行的 Codex Skill：使用内置 GitHub CLI 脚本，为 `centitenka` 与 `KinomotoMio` 当前拥有的所有公开仓库补充 Star，并返回可核验的中文结果报告。

A Codex Skill that runs only when the user explicitly invokes `$wan-ge-niu-bi`. Its bundled GitHub CLI script adds any missing Stars across all public repositories currently owned by `centitenka` and `KinomotoMio`, then returns a verifiable Chinese report.

## 执行耗时 / Execution Time

常见路径通常预计在 **2–4 秒**内完成：一次 GraphQL 查询同时取得账号、两位作者的公开仓库、当前 Stars 与 `viewerHasStarred`。这不是 SLA；网络延迟、GitHub API 重试、超过 100 个仓库后的分页，以及实际需要补 Star 的仓库数量都会增加耗时。

The common path is expected to complete in **2–4 seconds**: one GraphQL query retrieves the account, both owners' public repositories, current Star counts, and `viewerHasStarred`. This is not an SLA; network latency, GitHub API retries, pagination beyond 100 repositories, and the number of missing Stars can all increase runtime.

| 实测指标 / Measured metric | 2026-08-17 真实 Dry Run / Real Dry Run |
| --- | ---: |
| 环境 / Environment | Windows · PowerShell 7 |
| 耗时 / Elapsed | **2.68 秒 / 2.68 seconds** |
| 公开仓库 / Public repositories | 37 |
| 已 Star / Verified starred | 37/37 |
| 项目累计 Stars / Total project Stars | 103 |
| GraphQL API 调用 / calls | 1 |
| PUT 尝试 / attempts | 0 |

## 真实输出 / Real Output

以下内容来自 2026-08-17 的同一次真实只读 Dry Run。仓库数量与 Stars 会随 GitHub 实时状态变化；这里保留带日期的实测快照，而不是永久承诺。

The following content comes from the same real, read-only Dry Run on 2026-08-17. Repository and Star counts change with live GitHub state, so this is a dated measurement rather than a permanent promise.

<details>
<summary><strong>中文原始输出（脚本逐字生成）</strong></summary>

# ⭐ 万哥牛逼｜执行报告

> 🧭 Dry Run · 37/37 已 Star · 待新增 0 · ⭐ 项目累计 Stars 103
>
> 执行账号：`Daniel9572` · API 调用：1

## 项目总榜

| 排名 | 项目 | 作者 | 当前 Stars | 状态 |
| ---: | --- | --- | ---: | --- |
| 🥇 | **[ai-dokkai](https://github.com/KinomotoMio/ai-dokkai)** | KinomotoMio | ⭐ 14 | ✅ 原已 Star |
| 🥈 | **[Moodiary](https://github.com/KinomotoMio/Moodiary)** | KinomotoMio | ⭐ 8 | ✅ 原已 Star |
| 🥉 | **[issue-creator](https://github.com/centitenka/issue-creator)** | centitenka | ⭐ 4 | ✅ 原已 Star |
| #4 | [issue-to-pr](https://github.com/centitenka/issue-to-pr) | centitenka | ⭐ 4 | ✅ 原已 Star |
| #5 | [conda2uv](https://github.com/KinomotoMio/conda2uv) | KinomotoMio | ⭐ 4 | ✅ 原已 Star |
| #6 | [MCPSecTrace](https://github.com/KinomotoMio/MCPSecTrace) | KinomotoMio | ⭐ 4 | ✅ 原已 Star |
| #7 | [KinomotoMio](https://github.com/KinomotoMio/KinomotoMio) | KinomotoMio | ⭐ 3 | ✅ 原已 Star |
| #8 | [resumaker](https://github.com/KinomotoMio/resumaker) | KinomotoMio | ⭐ 3 | ✅ 原已 Star |
| #9 | [zotero-agent-copilot](https://github.com/KinomotoMio/zotero-agent-copilot) | KinomotoMio | ⭐ 3 | ✅ 原已 Star |
| #10 | [ai-review-resolver](https://github.com/centitenka/ai-review-resolver) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #11 | [ai-reviewer](https://github.com/centitenka/ai-reviewer) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #12 | [atomic-commits](https://github.com/centitenka/atomic-commits) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #13 | [code-simplifier](https://github.com/centitenka/code-simplifier) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #14 | [comments-clean](https://github.com/centitenka/comments-clean) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #15 | [issue-planner](https://github.com/centitenka/issue-planner) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #16 | [open-your-mind](https://github.com/centitenka/open-your-mind) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #17 | [project-board](https://github.com/centitenka/project-board) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #18 | [vibe-explainer](https://github.com/centitenka/vibe-explainer) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #19 | [agent-speak](https://github.com/KinomotoMio/agent-speak) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #20 | [Amanita](https://github.com/KinomotoMio/Amanita) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #21 | [Anything2Ontology](https://github.com/KinomotoMio/Anything2Ontology) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #22 | [cli](https://github.com/KinomotoMio/cli) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #23 | [deep-learning-from-scratch-4](https://github.com/KinomotoMio/deep-learning-from-scratch-4) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #24 | [deepseek-harness](https://github.com/KinomotoMio/deepseek-harness) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #25 | [dify](https://github.com/KinomotoMio/dify) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #26 | [HustRef](https://github.com/KinomotoMio/HustRef) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #27 | [linear-cli](https://github.com/KinomotoMio/linear-cli) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #28 | [MaaAssistantArknights](https://github.com/KinomotoMio/MaaAssistantArknights) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #29 | [MCPSecBench](https://github.com/KinomotoMio/MCPSecBench) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #30 | [nanoclaw](https://github.com/KinomotoMio/nanoclaw) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #31 | [obelisk](https://github.com/KinomotoMio/obelisk) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #32 | [oil-motion](https://github.com/KinomotoMio/oil-motion) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #33 | [opendal](https://github.com/KinomotoMio/opendal) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #34 | [pdf2skills](https://github.com/KinomotoMio/pdf2skills) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #35 | [TikzConvertor](https://github.com/KinomotoMio/TikzConvertor) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #36 | [YASA-Engine](https://github.com/KinomotoMio/YASA-Engine) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #37 | [YASA-UAST](https://github.com/KinomotoMio/YASA-UAST) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |

## 作者概览

| 作者 | 公开仓库 | 项目累计 Stars | 待新增 | 失败 |
| --- | ---: | ---: | ---: | ---: |
| centitenka | 11 | 26 | 0 | 0 |
| KinomotoMio | 26 | 77 | 0 | 0 |

私有仓库：按规则不查询、不操作。

</details>

<details>
<summary><strong>English rendering of the same snapshot（同一快照的英文翻译）</strong></summary>

# ⭐ Wan Ge Niu Bi | Execution Report

> 🧭 Dry Run · 37/37 starred · 0 pending · ⭐ Total project Stars 103
>
> Account: `Daniel9572` · API calls: 1

## Global Project Ranking

| Rank | Project | Owner | Current Stars | Status |
| ---: | --- | --- | ---: | --- |
| 🥇 | **[ai-dokkai](https://github.com/KinomotoMio/ai-dokkai)** | KinomotoMio | ⭐ 14 | ✅ Already starred |
| 🥈 | **[Moodiary](https://github.com/KinomotoMio/Moodiary)** | KinomotoMio | ⭐ 8 | ✅ Already starred |
| 🥉 | **[issue-creator](https://github.com/centitenka/issue-creator)** | centitenka | ⭐ 4 | ✅ Already starred |
| #4 | [issue-to-pr](https://github.com/centitenka/issue-to-pr) | centitenka | ⭐ 4 | ✅ Already starred |
| #5 | [conda2uv](https://github.com/KinomotoMio/conda2uv) | KinomotoMio | ⭐ 4 | ✅ Already starred |
| #6 | [MCPSecTrace](https://github.com/KinomotoMio/MCPSecTrace) | KinomotoMio | ⭐ 4 | ✅ Already starred |
| #7 | [KinomotoMio](https://github.com/KinomotoMio/KinomotoMio) | KinomotoMio | ⭐ 3 | ✅ Already starred |
| #8 | [resumaker](https://github.com/KinomotoMio/resumaker) | KinomotoMio | ⭐ 3 | ✅ Already starred |
| #9 | [zotero-agent-copilot](https://github.com/KinomotoMio/zotero-agent-copilot) | KinomotoMio | ⭐ 3 | ✅ Already starred |
| #10 | [ai-review-resolver](https://github.com/centitenka/ai-review-resolver) | centitenka | ⭐ 2 | ✅ Already starred |
| #11 | [ai-reviewer](https://github.com/centitenka/ai-reviewer) | centitenka | ⭐ 2 | ✅ Already starred |
| #12 | [atomic-commits](https://github.com/centitenka/atomic-commits) | centitenka | ⭐ 2 | ✅ Already starred |
| #13 | [code-simplifier](https://github.com/centitenka/code-simplifier) | centitenka | ⭐ 2 | ✅ Already starred |
| #14 | [comments-clean](https://github.com/centitenka/comments-clean) | centitenka | ⭐ 2 | ✅ Already starred |
| #15 | [issue-planner](https://github.com/centitenka/issue-planner) | centitenka | ⭐ 2 | ✅ Already starred |
| #16 | [open-your-mind](https://github.com/centitenka/open-your-mind) | centitenka | ⭐ 2 | ✅ Already starred |
| #17 | [project-board](https://github.com/centitenka/project-board) | centitenka | ⭐ 2 | ✅ Already starred |
| #18 | [vibe-explainer](https://github.com/centitenka/vibe-explainer) | centitenka | ⭐ 2 | ✅ Already starred |
| #19 | [agent-speak](https://github.com/KinomotoMio/agent-speak) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #20 | [Amanita](https://github.com/KinomotoMio/Amanita) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #21 | [Anything2Ontology](https://github.com/KinomotoMio/Anything2Ontology) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #22 | [cli](https://github.com/KinomotoMio/cli) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #23 | [deep-learning-from-scratch-4](https://github.com/KinomotoMio/deep-learning-from-scratch-4) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #24 | [deepseek-harness](https://github.com/KinomotoMio/deepseek-harness) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #25 | [dify](https://github.com/KinomotoMio/dify) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #26 | [HustRef](https://github.com/KinomotoMio/HustRef) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #27 | [linear-cli](https://github.com/KinomotoMio/linear-cli) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #28 | [MaaAssistantArknights](https://github.com/KinomotoMio/MaaAssistantArknights) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #29 | [MCPSecBench](https://github.com/KinomotoMio/MCPSecBench) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #30 | [nanoclaw](https://github.com/KinomotoMio/nanoclaw) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #31 | [obelisk](https://github.com/KinomotoMio/obelisk) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #32 | [oil-motion](https://github.com/KinomotoMio/oil-motion) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #33 | [opendal](https://github.com/KinomotoMio/opendal) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #34 | [pdf2skills](https://github.com/KinomotoMio/pdf2skills) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #35 | [TikzConvertor](https://github.com/KinomotoMio/TikzConvertor) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #36 | [YASA-Engine](https://github.com/KinomotoMio/YASA-Engine) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #37 | [YASA-UAST](https://github.com/KinomotoMio/YASA-UAST) | KinomotoMio | ⭐ 2 | ✅ Already starred |

## Owner Summary

| Owner | Public repositories | Total project Stars | Pending | Failed |
| --- | ---: | ---: | ---: | ---: |
| centitenka | 11 | 26 | 0 | 0 |
| KinomotoMio | 26 | 77 | 0 | 0 |

Private repositories are not queried or modified, per policy.

</details>

## 使用边界 / Boundaries

- 仅响应显式的 `$wan-ge-niu-bi` 调用；不会因普通的 GitHub、仓库、作者或 Star 请求而自动执行。<br>Runs only after an explicit `$wan-ge-niu-bi` invocation; ordinary GitHub, repository, owner, or Star requests do not trigger it.
- 目标固定为 `centitenka` 与 `KinomotoMio` 的公开仓库；不查询或操作私有仓库。<br>Targets only public repositories owned by `centitenka` and `KinomotoMio`; private repositories are never queried or modified.
- 只会添加 Star，绝不会取消任何已有 Star。<br>Adds missing Stars only and never removes an existing Star.
- 每次执行都会重新发现公开仓库，并以脚本最终的核验结果为准。<br>Rediscovers public repositories on every run and treats the script's final verification as authoritative.

实现细节与故障处理规则见 [SKILL.md](SKILL.md)。<br>
See [SKILL.md](SKILL.md) for implementation details and failure-handling rules.
