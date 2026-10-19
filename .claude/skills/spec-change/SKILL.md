---
name: spec-change
description: Change docs/SPEC.md safely — decision record, balance data, tests and code updated together so spec and implementation never drift apart.
argument-hint: "<what should change and why>"
disable-model-invocation: true
allowed-tools: Bash(tail -n 25 docs/DECISIONS.md) Bash(tools/check.sh)
---

# Spec change: $ARGUMENTS

Latest decisions:

!`tail -n 25 docs/DECISIONS.md`

1. **Restate** the change in one or two sentences and list every spec section, `data/balance.json` key, test and code file it affects (search for them; don't guess). If the request is ambiguous, ask before editing.
2. **Confirm** with the user when the change alters gameplay, scope or platforms. Pure clarifications and typo fixes need no confirmation.
3. **Record first:** append a new `D-NNN` entry to `docs/DECISIONS.md` (next number, today's date, Decision / Why / Affects). Never edit old entries; supersede them.
4. **Edit `docs/SPEC.md`.** Keep its style: short sentences, tables for data, every number in one place.
5. **Propagate in the same change:** `data/balance.json`, tests (update fixtures to the new spec numbers first and watch them fail), then code until they pass. Update milestone rows if scope moved.
6. Run `tools/check.sh`, then the `spec-auditor` subagent on the affected sections. Fix all drift.
7. Commit as `spec: <summary> (D-NNN)`.
