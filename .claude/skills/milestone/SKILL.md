---
name: milestone
description: Implement one milestone from docs/SPEC.md end to end — plan, tests first, minimal code, quality gate, review, spec audit, progress update, commit.
argument-hint: "[M#]"
disable-model-invocation: true
allowed-tools: Bash(cat docs/PROGRESS.md) Bash(git log:*) Bash(tools/check.sh)
---

# Implement milestone $ARGUMENTS

Current progress:

!`cat docs/PROGRESS.md`

Recent history:

!`git log --oneline -10 2>/dev/null || echo "(no commits yet)"`

Follow these steps in order. Do not skip steps; do not start the next milestone.

1. **Understand.** Read `CLAUDE.md`, then the `docs/SPEC.md` sections that $ARGUMENTS depends on, its "Done when" row, and `docs/DECISIONS.md`. Read the existing code you will touch. If a previous milestone is not `done`, stop and say so.
2. **Clarify.** If anything in scope is ambiguous or contradictory, ask the user now — one short list of questions. Do not guess. If the spec looks wrong, propose `/spec-change` instead of working around it.
3. **Plan small.** Write a plan of at most 10 bullets: files to change (prefer existing ones), functions, tests. For each new abstraction, name its second user; if there is none, don't create it. Mark $ARGUMENTS `in progress` in `docs/PROGRESS.md`.
4. **Tests first.** For everything in `logic/`, write GUT tests that encode the spec's rules and numbers (the Sample tiers table is the fixture for formulas). Run them and see them fail for the right reason.
5. **Implement the minimum** that makes the tests pass and meets "Done when": touch, mouse, keyboard and gamepad; portrait and landscape (one code path per screen via the `Ui` helpers). Remove the `TODO($ARGUMENTS)` markers you resolve.
6. **Gate.** Run `tools/check.sh` until it passes. Never weaken a test, a lint limit or a drift rule to get green; if a rule is truly wrong, stop and ask.
7. **Review.** Launch the `reviewer` and `spec-auditor` subagents in parallel (auditor scope: $ARGUMENTS). Fix every "must fix" and every drift item. Apply "should fix" items unless they add code. Re-run `tools/check.sh`.
8. **Simplify pass.** Re-read your diff once more and delete anything not needed for "Done when".
9. **Record.** Set $ARGUMENTS to `done` in `docs/PROGRESS.md` with a one-line note, and add a play-test checklist under "Play-test notes" (phone portrait 540 × 960, Deck landscape 1280 × 800, keyboard, gamepad).
10. **Commit** with message `$ARGUMENTS: <one-line summary>`.
11. **Report** to the user in under 15 lines: what was built, how to play-test it, anything deferred or decided, and any open question.
