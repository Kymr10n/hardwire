# Hardwire: Boot Sequence

[![CI](https://github.com/Kymr10n/hardwire/actions/workflows/ci.yml/badge.svg)](https://github.com/Kymr10n/hardwire/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf.svg)](https://godotengine.org)

An endless incremental puzzle game for phones and the Steam Deck. Upgrade a computer by solving three short memory and timing minigames: each one raises a stat, and higher stats unlock harder puzzle slots that pay out more. Open source (MIT), with no ads, in-app purchases or tracking.

| Overview | Storage | RAM | CPU |
| :---: | :---: | :---: | :---: |
| ![Overview with tier rows and slot cards](docs/screenshots/overview.png) | ![Storage: repeat the color sequence](docs/screenshots/storage.png) | ![RAM: recreate the pattern](docs/screenshots/ram.png) | ![CPU: copy the rhythm](docs/screenshots/cpu.png) |

## Status

Playable prototype (version 0.2.0). All three minigames, the tier overview, the upgrade shop, prestige ("Rebuild") and idle income are in; it runs on Linux / Steam Deck, Windows and the web with touch, mouse, keyboard or gamepad. The Android build, iOS and play-tests on real devices are still to come. Status and open follow-ups are in [`docs/PROGRESS.md`](docs/PROGRESS.md); the milestones are in the [spec](docs/SPEC.md#milestones-and-acceptance-criteria).

## How it plays

- **Storage** (raises STO): pads light up in sequence; tap them back in order.
- **RAM** (raises RAM): a pattern flashes on a grid; recreate it from memory.
- **CPU** (raises CPU): the tile plays a rhythm; copy it by holding and releasing.
- Puzzles take 10 to 40 seconds. A failure costs nothing; a fresh sequence starts right away.
- Slots unlock only when every stat meets the requirement, so no minigame can be skipped. From tier 8, modifiers such as *Reverse*, *Rotated* or *Syncopated* change the rules.
- Spend Cycles on upgrades, Rebuild for permanent Cores, and collect idle Cycles when you come back.

The full design, including every formula, is in [`docs/SPEC.md`](docs/SPEC.md). Every tuning number lives in [`data/balance.json`](data/balance.json).

## Run it

Requirements: [Godot 4.7.2](https://godotengine.org/download) (standard build, not .NET), with `godot` on your PATH.

```bash
git clone https://github.com/Kymr10n/hardwire.git
cd hardwire
godot --headless --path . --import   # first run: import assets
godot --path .                        # play in a 1280x800 window (Steam Deck size)
```

Use the mouse as your finger (touch is emulated), or a gamepad / keyboard: D-pad or arrows move the focus, A / Enter / Space selects (and is the CPU tile), B / Esc goes back, Y / C commits a RAM pattern. Make the window taller than wide to get the phone layout. In debug builds, F1 (or 5 taps on the stat bar) opens the debug panel, where you can set stats and tiers and force a minigame or modifier.

## Develop

Requirements: Godot 4.7.2 and Python 3 (for gdtoolkit). GUT is vendored in `addons/gut`.

```bash
tools/setup.sh       # once: gdtoolkit (gdformat, gdlint) into .venv, version checks
tools/check.sh       # the quality gate: format, lint, drift checks, script errors, tests
godot -e --path .    # open the editor
```

`tools/check.sh` is the same gate CI runs. Its drift checks keep code, tests and docs consistent: every `logic/` file has a mirrored test in `tests/logic/`, no tuning numbers in game logic, no duplicated blocks, short functions, input only through InputMap actions. VS Code users get tasks for the gate, for running the game as Steam Deck or phone, and for deploying to a Steam Deck.

| Path | Contents |
| --- | --- |
| `docs/SPEC.md` | Game design spec: source of truth, milestones, acceptance criteria |
| `docs/DECISIONS.md` | Why the spec is what it is (append-only decision log) |
| `docs/PROGRESS.md` | Milestone status and play-test notes |
| `data/balance.json` | Every tuning number, read through the `Balance` autoload |
| `autoload/` | Singletons: Balance, GameState, SaveManager, InputMode (glyphs), Synth (generated audio), Haptics |
| `logic/` | Pure, unit-tested rules: generators, rhythm judge, economy, progress |
| `scenes/` | Main scene, screens, the three puzzles, UI components (built in code with `Ui` helpers) |
| `theme/` | Colors, sizes and durations |
| `tests/` | GUT tests; `tests/logic/` mirrors `logic/` |
| `tools/` | Setup, quality gate, drift checks, exports, Steam Deck deploy, Steam upload, pinned versions |

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

### Working with Claude Code

The project is developed with [Claude Code](https://claude.com/claude-code) under a small harness. [`CLAUDE.md`](CLAUDE.md) holds the rules (KISS, DRY, YAGNI, architecture, platforms, tests), which apply to human contributors too.

| What | How |
| --- | --- |
| Build the next milestone | `/milestone M#`: plan, tests first, minimal code, gate, review, progress, commit |
| Change the design | `/spec-change <what and why>`: decision record, spec, data, tests and code together |
| Review ad-hoc changes | `/review`: the gate plus the read-only `reviewer` and `spec-auditor` agents |

Hooks in `.claude/settings.json` protect generated files and past decisions, format and lint every edit, and run `tools/check.sh` before Claude finishes a turn.

## Export

Presets for Linux (Steam Deck), Windows, macOS, Android and Web are in `export_presets.cfg`. Install the Godot 4.7.2 export templates first (Editor → Manage Export Templates).

```bash
tools/export.sh Linux build/linux/hardwire.x86_64   # Linux / Steam Deck (single file, PCK embedded)
tools/export.sh Windows build/windows/hardwire.exe  # Windows (single file)
tools/export.sh macOS build/macos/hardwire.zip      # macOS (unsigned; signing needs a Mac)
tools/export.sh Web build/web/index.html            # Web (single-threaded; serve over HTTPS or localhost)

# Android (needs the Android SDK and JDK 17 in Editor Settings → Export → Android)
godot --headless --path . --export-debug "Android" build/android/hardwire.apk
```

CI builds the Linux, Windows and web exports on every push to `main` (not on pull requests) and attaches them as artifacts.

**Releases.** Set `config/version` in `project.godot` (the export presets must match; `tools/check.sh` checks), add the version's section to `CHANGELOG.md`, then `git tag v<version> && git push origin v<version>`. The Release workflow builds every platform and publishes the GitHub release with the builds, the Steam Deck installer and that CHANGELOG section as notes; the one-click Deck install picks it up from then on.

### Steam Deck

**One-click install.** On the Deck, switch to Desktop Mode and open this page in the browser:

1. Download [Hardwire-SteamDeck.desktop](https://github.com/Kymr10n/hardwire/releases/latest/download/Hardwire-SteamDeck.desktop).
2. Open the Downloads folder and double-click it. If Dolphin asks whether to run a file that is not marked executable, choose "Continue".
3. A terminal shows the steps: it downloads the latest release into `~/Games/hardwire`, closes Steam for a moment, adds "Hardwire: Boot Sequence" to your library and starts Steam again. When it says "Done", switch back to Game Mode and press Play.

Run the same file again whenever you want to update. If the controls don't respond in Game Mode, pick the "Gamepad" layout in the game's Steam controller settings. (What it runs: `tools/steamdeck_install.sh` and `tools/steamdeck_shortcut.py`.)

The game is a single file, `hardwire.x86_64`, that Steam runs like any non-Steam game: it starts fullscreen (Steam sets `SteamDeck=1`) and plays with touch or the built-in controls. Without the installer: copy a release's `hardwire-<version>-linux-x86_64` to `~/Games/hardwire/hardwire.x86_64`, mark it executable (right-click → Properties → Permissions) and add it in Steam → Add a Game → Add a Non-Steam Game.

**Deploying over SSH (development).** On the Deck in Desktop Mode, open Konsole: `passwd` (set a password), then `sudo systemctl enable --now sshd`. On the dev PC: `ssh-copy-id deck@steamdeck` and, if the Deck has another address, `echo 'DECK=deck@<host-or-ip>' > tools/deck.local.env` (git-ignored). Then every `tools/deck.sh` (or the VS Code task "Deploy: Steam Deck") exports the Linux build and copies it into place; `--run` also starts it in Desktop Mode, `--no-export` copies the existing build. For log output, run the binary over `ssh` while the Deck is in Desktop Mode.

### Steam

`tools/steam_upload.sh` exports Linux and Windows and uploads them with SteamPipe; `--preview` builds the manifests without uploading. It needs `steamcmd` on PATH and a git-ignored `tools/steam.local.env` with `STEAM_APP_ID`, `STEAM_DEPOT_LINUX`, `STEAM_DEPOT_WINDOWS` and `STEAM_USER`, and it only uploads a committed tree. Set the uploaded build live by hand in Steamworks → Builds. The Steamworks settings (launch options, Steam Input, Auto-Cloud) are in the spec under "After the prototype: Steam release".

Desktop saves live in `~/.local/share/Hardwire` (Linux, Steam Deck) and `%APPDATA%\Hardwire` (Windows).

## License

Hardwire is released under the [MIT License](LICENSE). It uses the Godot Engine (MIT), the VT323 and DSEG fonts (SIL Open Font License 1.1) and, for tests only, GUT (MIT); see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The game lists all license texts under Settings → Licenses.
