# 万哥牛逼

[English](README.en.md) | [简体中文](README.md)

一个仅在用户显式调用 `$wan-ge-niu-bi` 时运行的 Codex Skill。它使用 GitHub CLI，为 `centitenka`、`KinomotoMio` 与 `proto-commons` 当前拥有的全部公开仓库补齐 Star，并返回简洁、可核验的中文报告。

## 平台支持

| 平台 | 入口 | 依赖 |
| --- | --- | --- |
| Windows | `scripts/invoke-wan-ge-niu-bi.ps1` | PowerShell 5.1+、GitHub CLI |
| Linux / macOS | `scripts/invoke-wan-ge-niu-bi.sh` | Bash 3.2+、GitHub CLI |

Unix 版本不依赖 Python、独立 `jq`、Node.js 或 PowerShell。两个入口都使用 `gh` 当前账号的正常用户凭据。

## 只读验证

```powershell
pwsh -NoProfile -File scripts/invoke-wan-ge-niu-bi.ps1 -DryRun -OutputFormat Json
```

```bash
bash scripts/invoke-wan-ge-niu-bi.sh --dry-run --output-format json
```

Dry Run 会重新发现全部目标公开仓库并核对 Star 状态，但不会发起任何 PUT。移除 Dry Run 参数后，脚本只为缺失项目添加 Star。

## 输出

JSON 只保留自动化所需字段：执行状态、账号、总数、作者统计、新增或待新增项目、失败详情、API 计数、退出码和 `markdown`。中文 Markdown 包含总览、作者概览、变更列表和失败详情，不生成体积较大的项目排行榜。

常见的“全部已 Star”路径只需一次 GraphQL 请求；脚本仅在 owner 超过 100 个公开仓库时分页，并只在实际新增后执行全量核验。

## 安全边界

- 仅响应显式的 `$wan-ge-niu-bi` 调用。
- 目标固定为三个 owner 的公开仓库；不查询或操作私有仓库。
- 只添加 Star，绝不取消已有 Star。
- 不读取或打印 GitHub token。
- 网络瞬时错误最多重试三次；失败会以状态和退出码明确返回。

执行和故障处理规则见 [SKILL.md](SKILL.md)。
