# 万哥牛逼

[English](README.en.md) | [简体中文](README.md)

一个通过 GitHub CLI，为 `centitenka`、`KinomotoMio` 和 `proto-commons` 名下全部公开仓库自动补齐 Star 的 Codex Skill。

## 功能

- 实时发现三个目标 owner 的全部公开仓库，包括 fork 和归档仓库。
- 仅为缺失项目添加 Star。
- 按当前 Star 数输出全部仓库的全局总榜。
- 直接输出适合聊天框展示的 Markdown。

## 平台支持

| 平台 | 入口 | 依赖 |
| --- | --- | --- |
| Windows | `scripts/invoke-wan-ge-niu-bi.ps1` | PowerShell 5.1+、GitHub CLI |
| Linux / macOS | `scripts/invoke-wan-ge-niu-bi.sh` | Bash 3.2+、GitHub CLI |

## 使用

```powershell
& scripts/invoke-wan-ge-niu-bi.ps1
```

```bash
bash scripts/invoke-wan-ge-niu-bi.sh
```

## 输出

脚本按 `Stars 降序 → 完整仓库名升序` 输出全部仓库。前三名使用 `🥇🥈🥉`，其余使用数字排名。全部仓库已 Star 时只需一次 GraphQL 请求；仅在实际写入后执行一次最终核验。

## 输出示例

以下为实际输出节选，完整输出包含全部 45 个仓库：

```text
✅ 45/45 已 Star，本次新增 0
账号：`Daniel9572`

| # | 仓库 | Stars |
| ---: | --- | ---: |
| 🥇 | [KinomotoMio/ai-dokkai](https://github.com/KinomotoMio/ai-dokkai) | 14 |
| 🥈 | [proto-commons/cc-persona](https://github.com/proto-commons/cc-persona) | 10 |
| 🥉 | [KinomotoMio/Moodiary](https://github.com/KinomotoMio/Moodiary) | 9 |
```

## 实测

2026-08-19 在 Windows PowerShell 5.1 环境中处理 45 个公开仓库，5 次真实运行取中位数：

| 项目 | 结果 |
| --- | ---: |
| 全部已 Star，并输出完整总榜 | 3.053 秒 |
| 执行结果输出 | 3,971 字符、4,001 bytes、约 1,001 tokens |
| `SKILL.md` 与执行结果 | 约 1,163 tokens |

## 安全边界

- 仅响应显式的 `$wan-ge-niu-bi` 调用。
- 目标 owner 固定，不接受外部替换。
- 不查询或操作私有仓库。
- 只添加 Star，绝不取消已有 Star。
- 不读取或打印 GitHub token。
