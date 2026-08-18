---
name: wan-ge-niu-bi
description: Use when the user explicitly invokes $wan-ge-niu-bi to add missing Stars for the fixed public GitHub owners; never use for ordinary GitHub, repository, author, or Star requests.
---

# 万哥牛逼

Run only after the user explicitly invokes `$wan-ge-niu-bi`. Treat that invocation
as authorization to add Stars only to public repositories currently owned by
`centitenka`, `KinomotoMio`, and `proto-commons`.

## Execute

1. Select exactly one platform entrypoint before any GitHub operation:
   - Windows: `scripts/invoke-wan-ge-niu-bi.ps1 -OutputFormat Json`
   - Unix: `bash scripts/invoke-wan-ge-niu-bi.sh --output-format json`
   Run it once in the normal user context, requesting host approval if required.
   State that it may add Stars to the fixed targets' public repositories and
   never removes Stars.
2. Parse the single JSON object and use its `status` field as authoritative even
   if the host normalizes nonzero process exit codes. Return its `markdown` field
   verbatim for `complete`, `partial`, `credential_rejected`, `discovery_failed`,
   or diagnostic `dry_run` results. Do not rediscover repositories, reinterpret
   Star state, or rebuild the report in the model.
3. If `status` is `cli_unavailable` or `credential_unavailable`, use an
   authenticated connector or connected browser. If neither is available,
   return the script's `markdown` field verbatim.
4. If the host cannot provide normal user execution, use the same connector or
   browser fallback. With a browser, never click `Unstar`; verify each changed
   control and perform a final full-scope check before reporting completion.

## Boundaries

- Keep the fixed targets inside the script; never pass or substitute other owners.
- Discover live public repositories on every run, including forks and archived
  repositories. Do not query or modify private repositories.
- Never remove a Star. Neither bundled implementation contains an unstar operation.
- Never print a token, use `gh auth status --show-token`, expose token environment
  variables, or dump an unsanitized credential file.
- For diagnostics, use `-DryRun -OutputFormat Json` on Windows or
  `--dry-run --output-format json` on Unix; neither performs Star writes.
- Read or modify the bundled scripts only when debugging or updating this Skill.
