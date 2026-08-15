---
name: wan-ge-niu-bi
description: Deterministically star every public GitHub repository currently owned by centitenka and KinomotoMio with the bundled GitHub CLI scripts, then return a verified Chinese report. Use only when the user explicitly invokes $wan-ge-niu-bi; never invoke it implicitly from ordinary GitHub, repository, author, or Star requests.
---

# 万哥牛逼

Run only after the user explicitly invokes `$wan-ge-niu-bi`. Treat that invocation
as authorization to add Stars only to public repositories currently owned by
`centitenka` and `KinomotoMio`.

## Execute

1. Run `scripts/invoke-wan-ge-niu-bi.ps1 -OutputFormat Markdown`.
2. If it exits `10` from a restricted or sandboxed process, rerun the same script
   once in the normal user context. Do not diagnose token expiry from the
   restricted-context result.
3. On exit `0`, return the script's Markdown output verbatim. Do not rediscover
   repositories, reinterpret Star state, or rebuild the report in the model.
4. Report nonzero results precisely:
   - `10`: GitHub CLI or its credential is unavailable to the current context.
   - `11`: a visible credential was rejected by GitHub.
   - `20`: live repository or Star discovery failed.
   - `30`: one or more repositories remain unverified after the scripted run.
5. Use an authenticated connector or connected browser only if deterministic CLI
   execution remains unavailable in the normal user context. With a browser,
   never click `Unstar`; verify each changed control and perform a final full-scope
   check before reporting completion.

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
