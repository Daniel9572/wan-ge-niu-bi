# Wan Ge Niu Bi

[English](README.en.md) | [简体中文](README.md)

A Codex Skill that runs only when the user explicitly invokes `$wan-ge-niu-bi`. It uses GitHub CLI to add missing Stars across all public repositories currently owned by `centitenka`, `KinomotoMio`, and `proto-commons`, then returns a concise, verifiable Chinese report.

## Platform Support

| Platform | Entrypoint | Requirements |
| --- | --- | --- |
| Windows | `scripts/invoke-wan-ge-niu-bi.ps1` | PowerShell 5.1+, GitHub CLI |
| Linux / macOS | `scripts/invoke-wan-ge-niu-bi.sh` | Bash 3.2+, GitHub CLI |

The Unix implementation does not require Python, standalone `jq`, Node.js, or PowerShell. Both entrypoints use the normal credentials of the account currently authenticated in `gh`.

## Read-only Validation

```powershell
pwsh -NoProfile -File scripts/invoke-wan-ge-niu-bi.ps1 -DryRun -OutputFormat Json
```

```bash
bash scripts/invoke-wan-ge-niu-bi.sh --dry-run --output-format json
```

Dry Run rediscovers every target public repository and checks Star state without issuing a PUT. Removing the Dry Run flag allows the script to add only missing Stars.

## Output

JSON contains only fields needed by automation: status, account, totals, owner summaries, added or pending repositories, failures, API counts, exit code, and `markdown`. The Chinese Markdown report contains a summary, owner overview, changes, and failures instead of a large project ranking.

The common all-starred path uses one GraphQL request. Pagination occurs only when an owner has more than 100 public repositories, and full verification occurs only after a write is needed.

## Safety Boundaries

- Runs only after an explicit `$wan-ge-niu-bi` invocation.
- Targets public repositories of the three fixed owners; private repositories are never queried or modified.
- Adds Stars only and never removes an existing Star.
- Never reads or prints a GitHub token.
- Retries transient network failures up to three times and returns explicit statuses and exit codes.

See [SKILL.md](SKILL.md) for execution and failure-handling rules.
