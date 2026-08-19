---
name: wan-ge-niu-bi
description: Use only when the user explicitly invokes $wan-ge-niu-bi. Add missing Stars to public repositories owned by centitenka, KinomotoMio, and proto-commons, then return the complete ranking by current Stars.
---

Run one entrypoint in the normal user context; request host approval if needed:

- Windows: `& scripts/invoke-wan-ge-niu-bi.ps1`
- Unix: `bash scripts/invoke-wan-ge-niu-bi.sh`

Return stdout verbatim. Keep the scripted targets, include public forks and archived repositories, never query private repositories, unstar, or expose a token. Sort by Stars descending, then full repository name ascending.
