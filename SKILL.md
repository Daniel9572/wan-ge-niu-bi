---
name: wan-ge-niu-bi
description: Deterministically star every public GitHub repository currently owned by centitenka and KinomotoMio with the bundled GitHub CLI scripts, then return a verified Chinese report. Use only when the user explicitly invokes $wan-ge-niu-bi; never invoke it implicitly from ordinary GitHub, repository, author, or Star requests.
---

# 万哥牛逼

Run only after the user explicitly invokes `$wan-ge-niu-bi`. Treat that invocation
as authorization to add Stars only to public repositories currently owned by
`centitenka` and `KinomotoMio`.

## Execute

1. Make the first GitHub operation a single run of
   `scripts/invoke-wan-ge-niu-bi.ps1 -OutputFormat Json` in the normal user
   context, requesting host approval if required. State in the approval request
   that the command may add Stars to the fixed targets' public repositories and
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
- Never remove a Star. The bundled implementation contains no unstar operation.
- Never print a token, use `gh auth status --show-token`, expose token environment
  variables, or dump an unsanitized credential file.
- Use `-DryRun -OutputFormat Json` only for diagnostics or validation; it performs
  no Star writes.
- Read or modify the bundled scripts only when debugging or updating this Skill.
