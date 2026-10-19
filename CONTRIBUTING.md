# Contributing to Hardwire

Thanks for helping! Bug reports, balance feedback from play-testing, and pull requests are all welcome.

## Before you start

- Read [`docs/SPEC.md`](docs/SPEC.md). It is the source of truth for how the game works. If your change alters behaviour or a number, update the spec in the same pull request and add a new entry to [`docs/DECISIONS.md`](docs/DECISIONS.md) saying why (CI enforces this; old entries are never edited).
- For anything bigger than a bug fix, open an issue first so we can agree on the approach.
- Hardwire has no ads, analytics, tracking or purchases, and won't accept them.

## Setup and rules

- Setup, commands and the project layout: [README → Develop](README.md#develop).
- Code rules (KISS, DRY, YAGNI, architecture, platforms, tests, size limits): [`CLAUDE.md`](CLAUDE.md). They apply to people as much as to Claude Code, and `tools/check.sh` enforces most of them.

## Pull requests

- Keep each pull request focused on one change, with a clear description.
- `tools/check.sh` must pass (the same gate CI runs). Never weaken a test or a limit to get green; if a rule is wrong, say so in the PR.
- If you changed something players can see, describe how to play-test it and add a line to [`CHANGELOG.md`](CHANGELOG.md).
- By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE).

## Reporting bugs

Use the bug report template. Include your platform (Steam Deck, Windows/Linux/macOS build, Android, web, or the editor), the build or commit, steps to reproduce, and what you expected.
