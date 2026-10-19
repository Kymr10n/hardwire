---
name: review
description: Run the quality gate and an independent review of the current uncommitted changes, then fix what it finds.
disable-model-invocation: true
allowed-tools: Bash(git status:*) Bash(git diff:*) Bash(tools/check.sh)
---

# Review current changes

!`git status --short`

1. Run `tools/check.sh`.
2. Launch the `reviewer` subagent on the current changes. If `docs/SPEC.md`, `data/balance.json` or anything in `logic/` changed, launch the `spec-auditor` subagent in parallel.
3. Fix every "must fix" and drift item; apply "should fix" items that remove code. Re-run `tools/check.sh`.
4. Summarize in a few lines what was found and what you changed.

Focus, if given: $ARGUMENTS
