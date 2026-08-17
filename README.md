# Wan Ge Niu Bi

[English](README.md) | [简体中文](README.zh-CN.md)

A Codex Skill that runs only when the user explicitly invokes `$wan-ge-niu-bi`. Its bundled GitHub CLI script adds any missing Stars across all public repositories currently owned by `centitenka`, `KinomotoMio`, and `proto-commons`, then returns a verifiable Chinese report.

## Execution Time

The common path is expected to complete in **2–4 seconds**: one GraphQL query retrieves the account, all three owners' public repositories, current Star counts, and `viewerHasStarred`. This is not an SLA; network latency, GitHub API retries, pagination beyond 100 repositories per owner, and the number of missing Stars can all increase runtime.

| Measured metric | Real Dry Run on 2026-08-17 |
| --- | ---: |
| Environment | Windows · PowerShell 7 |
| Elapsed | **2.33 seconds** |
| Public repositories | 44 |
| Verified starred | 44/44 |
| Total project Stars | 129 |
| GraphQL API calls | 1 |
| PUT attempts | 0 |

## Real Output

The following is an English rendering of the script output from the same real, read-only Dry Run on 2026-08-17. Repository and Star counts change with live GitHub state, so this is a dated measurement rather than a permanent promise.

<details>
<summary><strong>Show the complete 44-project report</strong></summary>

# ⭐ Wan Ge Niu Bi | Execution Report

> 🧭 Dry Run · 44/44 starred · 0 pending · ⭐ Total project Stars 129
>
> Account: `Daniel9572` · API calls: 1

## Global Project Ranking

| Rank | Project | Owner | Current Stars | Status |
| ---: | --- | --- | ---: | --- |
| 🥇 | **[ai-dokkai](https://github.com/KinomotoMio/ai-dokkai)** | KinomotoMio | ⭐ 14 | ✅ Already starred |
| 🥈 | **[cc-persona](https://github.com/proto-commons/cc-persona)** | proto-commons | ⭐ 10 | ✅ Already starred |
| 🥉 | **[Moodiary](https://github.com/KinomotoMio/Moodiary)** | KinomotoMio | ⭐ 8 | ✅ Already starred |
| #4 | [ZhiYan-Legacy](https://github.com/proto-commons/ZhiYan-Legacy) | proto-commons | ⭐ 7 | ✅ Already starred |
| #5 | [issue-creator](https://github.com/centitenka/issue-creator) | centitenka | ⭐ 4 | ✅ Already starred |
| #6 | [issue-to-pr](https://github.com/centitenka/issue-to-pr) | centitenka | ⭐ 4 | ✅ Already starred |
| #7 | [conda2uv](https://github.com/KinomotoMio/conda2uv) | KinomotoMio | ⭐ 4 | ✅ Already starred |
| #8 | [MCPSecTrace](https://github.com/KinomotoMio/MCPSecTrace) | KinomotoMio | ⭐ 4 | ✅ Already starred |
| #9 | [KinomotoMio](https://github.com/KinomotoMio/KinomotoMio) | KinomotoMio | ⭐ 3 | ✅ Already starred |
| #10 | [resumaker](https://github.com/KinomotoMio/resumaker) | KinomotoMio | ⭐ 3 | ✅ Already starred |
| #11 | [zotero-agent-copilot](https://github.com/KinomotoMio/zotero-agent-copilot) | KinomotoMio | ⭐ 3 | ✅ Already starred |
| #12 | [Browser-bg-swap](https://github.com/proto-commons/Browser-bg-swap) | proto-commons | ⭐ 3 | ✅ Already starred |
| #13 | [TV_Caster](https://github.com/proto-commons/TV_Caster) | proto-commons | ⭐ 3 | ✅ Already starred |
| #14 | [ai-review-resolver](https://github.com/centitenka/ai-review-resolver) | centitenka | ⭐ 2 | ✅ Already starred |
| #15 | [ai-reviewer](https://github.com/centitenka/ai-reviewer) | centitenka | ⭐ 2 | ✅ Already starred |
| #16 | [atomic-commits](https://github.com/centitenka/atomic-commits) | centitenka | ⭐ 2 | ✅ Already starred |
| #17 | [code-simplifier](https://github.com/centitenka/code-simplifier) | centitenka | ⭐ 2 | ✅ Already starred |
| #18 | [comments-clean](https://github.com/centitenka/comments-clean) | centitenka | ⭐ 2 | ✅ Already starred |
| #19 | [issue-planner](https://github.com/centitenka/issue-planner) | centitenka | ⭐ 2 | ✅ Already starred |
| #20 | [open-your-mind](https://github.com/centitenka/open-your-mind) | centitenka | ⭐ 2 | ✅ Already starred |
| #21 | [project-board](https://github.com/centitenka/project-board) | centitenka | ⭐ 2 | ✅ Already starred |
| #22 | [vibe-explainer](https://github.com/centitenka/vibe-explainer) | centitenka | ⭐ 2 | ✅ Already starred |
| #23 | [agent-speak](https://github.com/KinomotoMio/agent-speak) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #24 | [Amanita](https://github.com/KinomotoMio/Amanita) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #25 | [Anything2Ontology](https://github.com/KinomotoMio/Anything2Ontology) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #26 | [cli](https://github.com/KinomotoMio/cli) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #27 | [deep-learning-from-scratch-4](https://github.com/KinomotoMio/deep-learning-from-scratch-4) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #28 | [deepseek-harness](https://github.com/KinomotoMio/deepseek-harness) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #29 | [dify](https://github.com/KinomotoMio/dify) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #30 | [HustRef](https://github.com/KinomotoMio/HustRef) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #31 | [linear-cli](https://github.com/KinomotoMio/linear-cli) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #32 | [MaaAssistantArknights](https://github.com/KinomotoMio/MaaAssistantArknights) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #33 | [MCPSecBench](https://github.com/KinomotoMio/MCPSecBench) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #34 | [nanoclaw](https://github.com/KinomotoMio/nanoclaw) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #35 | [obelisk](https://github.com/KinomotoMio/obelisk) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #36 | [oil-motion](https://github.com/KinomotoMio/oil-motion) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #37 | [opendal](https://github.com/KinomotoMio/opendal) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #38 | [pdf2skills](https://github.com/KinomotoMio/pdf2skills) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #39 | [TikzConvertor](https://github.com/KinomotoMio/TikzConvertor) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #40 | [YASA-Engine](https://github.com/KinomotoMio/YASA-Engine) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #41 | [YASA-UAST](https://github.com/KinomotoMio/YASA-UAST) | KinomotoMio | ⭐ 2 | ✅ Already starred |
| #42 | [AIMoeMaker](https://github.com/proto-commons/AIMoeMaker) | proto-commons | ⭐ 1 | ✅ Already starred |
| #43 | [hopper](https://github.com/proto-commons/hopper) | proto-commons | ⭐ 1 | ✅ Already starred |
| #44 | [proto-skills](https://github.com/proto-commons/proto-skills) | proto-commons | ⭐ 1 | ✅ Already starred |

## Owner Summary

| Owner | Public repositories | Total project Stars | Pending | Failed |
| --- | ---: | ---: | ---: | ---: |
| centitenka | 11 | 26 | 0 | 0 |
| KinomotoMio | 26 | 77 | 0 | 0 |
| proto-commons | 7 | 26 | 0 | 0 |

Private repositories are not queried or modified, per policy.

</details>

## Boundaries

- Runs only after an explicit `$wan-ge-niu-bi` invocation; ordinary GitHub, repository, owner, or Star requests do not trigger it.
- Targets only public repositories owned by `centitenka`, `KinomotoMio`, and `proto-commons`; private repositories are never queried or modified.
- Adds missing Stars only and never removes an existing Star.
- Rediscovers public repositories on every run and treats the script's final verification as authoritative.

See [SKILL.md](SKILL.md) for implementation details and failure-handling rules.
