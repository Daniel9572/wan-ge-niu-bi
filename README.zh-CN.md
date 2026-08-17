# 万哥牛逼

[English](README.md) | [简体中文](README.zh-CN.md)

一个仅在用户显式调用 `$wan-ge-niu-bi` 时运行的 Codex Skill：使用内置 GitHub CLI 脚本，为 `centitenka`、`KinomotoMio` 与 `proto-commons` 当前拥有的所有公开仓库补充 Star，并返回可核验的中文结果报告。

## 执行耗时

常见路径通常预计在 **2–4 秒**内完成：一次 GraphQL 查询同时取得账号、三方的公开仓库、当前 Stars 与 `viewerHasStarred`。这不是 SLA；网络延迟、GitHub API 重试、任一方超过 100 个仓库后的分页，以及实际需要补 Star 的仓库数量都会增加耗时。

| 实测指标 | 2026-08-17 真实 Dry Run |
| --- | ---: |
| 环境 | Windows · PowerShell 7 |
| 耗时 | **2.33 秒** |
| 公开仓库 | 44 |
| 已 Star | 44/44 |
| 项目累计 Stars | 129 |
| GraphQL API 调用 | 1 |
| PUT 尝试 | 0 |

## 真实输出

以下内容来自 2026-08-17 的同一次真实只读 Dry Run，由脚本逐字生成。仓库数量与 Stars 会随 GitHub 实时状态变化；这里保留带日期的实测快照，而不是永久承诺。

<details>
<summary><strong>展开完整的 44 项目报告</strong></summary>

# ⭐ 万哥牛逼｜执行报告

> 🧭 Dry Run · 44/44 已 Star · 待新增 0 · ⭐ 项目累计 Stars 129
>
> 执行账号：`Daniel9572` · API 调用：1

## 项目总榜

| 排名 | 项目 | 作者 | 当前 Stars | 状态 |
| ---: | --- | --- | ---: | --- |
| 🥇 | **[ai-dokkai](https://github.com/KinomotoMio/ai-dokkai)** | KinomotoMio | ⭐ 14 | ✅ 原已 Star |
| 🥈 | **[cc-persona](https://github.com/proto-commons/cc-persona)** | proto-commons | ⭐ 10 | ✅ 原已 Star |
| 🥉 | **[Moodiary](https://github.com/KinomotoMio/Moodiary)** | KinomotoMio | ⭐ 8 | ✅ 原已 Star |
| #4 | [ZhiYan-Legacy](https://github.com/proto-commons/ZhiYan-Legacy) | proto-commons | ⭐ 7 | ✅ 原已 Star |
| #5 | [issue-creator](https://github.com/centitenka/issue-creator) | centitenka | ⭐ 4 | ✅ 原已 Star |
| #6 | [issue-to-pr](https://github.com/centitenka/issue-to-pr) | centitenka | ⭐ 4 | ✅ 原已 Star |
| #7 | [conda2uv](https://github.com/KinomotoMio/conda2uv) | KinomotoMio | ⭐ 4 | ✅ 原已 Star |
| #8 | [MCPSecTrace](https://github.com/KinomotoMio/MCPSecTrace) | KinomotoMio | ⭐ 4 | ✅ 原已 Star |
| #9 | [KinomotoMio](https://github.com/KinomotoMio/KinomotoMio) | KinomotoMio | ⭐ 3 | ✅ 原已 Star |
| #10 | [resumaker](https://github.com/KinomotoMio/resumaker) | KinomotoMio | ⭐ 3 | ✅ 原已 Star |
| #11 | [zotero-agent-copilot](https://github.com/KinomotoMio/zotero-agent-copilot) | KinomotoMio | ⭐ 3 | ✅ 原已 Star |
| #12 | [Browser-bg-swap](https://github.com/proto-commons/Browser-bg-swap) | proto-commons | ⭐ 3 | ✅ 原已 Star |
| #13 | [TV_Caster](https://github.com/proto-commons/TV_Caster) | proto-commons | ⭐ 3 | ✅ 原已 Star |
| #14 | [ai-review-resolver](https://github.com/centitenka/ai-review-resolver) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #15 | [ai-reviewer](https://github.com/centitenka/ai-reviewer) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #16 | [atomic-commits](https://github.com/centitenka/atomic-commits) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #17 | [code-simplifier](https://github.com/centitenka/code-simplifier) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #18 | [comments-clean](https://github.com/centitenka/comments-clean) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #19 | [issue-planner](https://github.com/centitenka/issue-planner) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #20 | [open-your-mind](https://github.com/centitenka/open-your-mind) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #21 | [project-board](https://github.com/centitenka/project-board) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #22 | [vibe-explainer](https://github.com/centitenka/vibe-explainer) | centitenka | ⭐ 2 | ✅ 原已 Star |
| #23 | [agent-speak](https://github.com/KinomotoMio/agent-speak) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #24 | [Amanita](https://github.com/KinomotoMio/Amanita) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #25 | [Anything2Ontology](https://github.com/KinomotoMio/Anything2Ontology) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #26 | [cli](https://github.com/KinomotoMio/cli) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #27 | [deep-learning-from-scratch-4](https://github.com/KinomotoMio/deep-learning-from-scratch-4) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #28 | [deepseek-harness](https://github.com/KinomotoMio/deepseek-harness) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #29 | [dify](https://github.com/KinomotoMio/dify) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #30 | [HustRef](https://github.com/KinomotoMio/HustRef) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #31 | [linear-cli](https://github.com/KinomotoMio/linear-cli) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #32 | [MaaAssistantArknights](https://github.com/KinomotoMio/MaaAssistantArknights) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #33 | [MCPSecBench](https://github.com/KinomotoMio/MCPSecBench) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #34 | [nanoclaw](https://github.com/KinomotoMio/nanoclaw) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #35 | [obelisk](https://github.com/KinomotoMio/obelisk) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #36 | [oil-motion](https://github.com/KinomotoMio/oil-motion) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #37 | [opendal](https://github.com/KinomotoMio/opendal) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #38 | [pdf2skills](https://github.com/KinomotoMio/pdf2skills) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #39 | [TikzConvertor](https://github.com/KinomotoMio/TikzConvertor) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #40 | [YASA-Engine](https://github.com/KinomotoMio/YASA-Engine) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #41 | [YASA-UAST](https://github.com/KinomotoMio/YASA-UAST) | KinomotoMio | ⭐ 2 | ✅ 原已 Star |
| #42 | [AIMoeMaker](https://github.com/proto-commons/AIMoeMaker) | proto-commons | ⭐ 1 | ✅ 原已 Star |
| #43 | [hopper](https://github.com/proto-commons/hopper) | proto-commons | ⭐ 1 | ✅ 原已 Star |
| #44 | [proto-skills](https://github.com/proto-commons/proto-skills) | proto-commons | ⭐ 1 | ✅ 原已 Star |

## 作者概览

| 作者 | 公开仓库 | 项目累计 Stars | 待新增 | 失败 |
| --- | ---: | ---: | ---: | ---: |
| centitenka | 11 | 26 | 0 | 0 |
| KinomotoMio | 26 | 77 | 0 | 0 |
| proto-commons | 7 | 26 | 0 | 0 |

私有仓库：按规则不查询、不操作。

</details>

## 使用边界

- 仅响应显式的 `$wan-ge-niu-bi` 调用；不会因普通的 GitHub、仓库、作者或 Star 请求而自动执行。
- 目标固定为 `centitenka`、`KinomotoMio` 与 `proto-commons` 的公开仓库；不查询或操作私有仓库。
- 只会添加 Star，绝不会取消任何已有 Star。
- 每次执行都会重新发现公开仓库，并以脚本最终的核验结果为准。

实现细节与故障处理规则见 [SKILL.md](SKILL.md)。
