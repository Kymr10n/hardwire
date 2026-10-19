# Hardwire

Endless memory and timing puzzle game for phones, built with Godot 4. Design: [`docs/SPEC.md`](docs/SPEC.md).

## Setup

1. Install the latest stable **Godot 4.x** (standard build, not .NET) from https://godotengine.org/download and make sure `godot` is on your PATH.
2. Open this folder in **VS Code** and install the recommended extensions when prompted (Godot Tools, Claude Code, EditorConfig).
3. Open the project once in the Godot editor (`godot -e --path .`) so it imports and generates its cache. If Godot asks to upgrade the project format, accept.
4. Install the test framework **GUT**: in the Godot editor open *AssetLib*, search "GUT", install it into `addons/gut`, then enable it under *Project → Project Settings → Plugins*.
5. In VS Code, set `godotTools.editorPath.godot4` in `.vscode/settings.json` if `godot` is not on your PATH.
6. Run with F5 (launch config "Run Hardwire") or the task "Run game". You should see the placeholder screen with "balance.json loaded: true".

## Working with Claude Code

Start a session in this folder and ask, for example:

> Read CLAUDE.md and docs/SPEC.md, then implement milestone M1.

Work one milestone per session and play-test after each.

## Layout

| Path | Contents |
| --- | --- |
| `docs/SPEC.md` | Game design spec, milestones, acceptance criteria |
| `data/balance.json` | Every tuning number |
| `autoload/` | Global singletons: Balance, GameState, SaveManager, Synth, Haptics |
| `logic/` | Pure, unit-tested game rules |
| `scenes/` | Main scene, screens, puzzles, UI components |
| `tests/` | GUT unit tests |
