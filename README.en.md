# Wan Ge Niu Bi

[English](README.en.md) | [简体中文](README.md)

A Codex Skill that uses GitHub CLI to add missing Stars across all public repositories owned by `centitenka`, `KinomotoMio`, and `proto-commons`.

## Features

- Discovers every public repository of the three target owners, including forks and archived repositories.
- Adds only missing Stars.
- Returns one global ranking of every repository by current Star count.
- Prints Markdown ready for display in chat.

## Platform Support

| Platform | Entrypoint | Requirements |
| --- | --- | --- |
| Windows | `scripts/invoke-wan-ge-niu-bi.ps1` | PowerShell 5.1+, GitHub CLI |
| Linux / macOS | `scripts/invoke-wan-ge-niu-bi.sh` | Bash 3.2+, GitHub CLI |

## Usage

```powershell
& scripts/invoke-wan-ge-niu-bi.ps1
```

```bash
bash scripts/invoke-wan-ge-niu-bi.sh
```

## Output

The scripts rank every repository by `Stars descending → full repository name ascending`. The top three use `🥇🥈🥉`; later entries use numeric ranks. The all-starred path uses one GraphQL request, and one final verification runs only after a write.

## Output Example

This is an excerpt from a real run; the complete output contains all 45 repositories:

```text
✅ 45/45 已 Star，本次新增 0
账号：`Daniel9572`

| # | 仓库 | Stars |
| ---: | --- | ---: |
| 🥇 | [KinomotoMio/ai-dokkai](https://github.com/KinomotoMio/ai-dokkai) | 14 |
| 🥈 | [proto-commons/cc-persona](https://github.com/proto-commons/cc-persona) | 10 |
| 🥉 | [KinomotoMio/Moodiary](https://github.com/KinomotoMio/Moodiary) | 9 |
```

## Measured Run

Measured on 2026-08-19 with Windows PowerShell 5.1 across 45 public repositories; values use the median of five real runs:

| Item | Result |
| --- | ---: |
| All repositories already starred with the complete ranking returned | 3.053 seconds |
| Execution output | 3,971 characters, 4,001 bytes, about 1,001 tokens |
| `SKILL.md` and execution output | About 1,163 tokens |

## Safety Boundaries

- Runs only after an explicit `$wan-ge-niu-bi` invocation.
- Target owners are fixed and cannot be replaced through arguments.
- Private repositories are never queried or modified.
- Adds Stars only and never removes an existing Star.
- Never reads or prints a GitHub token.
