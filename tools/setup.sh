#!/usr/bin/env bash
# One-time (and idempotent) setup: pinned gdtoolkit (gdformat, gdlint) in .venv and a Godot version check.
# GUT is vendored in addons/gut (pinned in tools/versions.env), so nothing to fetch for tests.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/versions.env
GODOT="${GODOT:-godot}"

if [ ! -x .venv/bin/gdlint ] || ! .venv/bin/gdlint --version | grep -q "$GDTOOLKIT_VERSION"; then
	echo "Installing gdtoolkit $GDTOOLKIT_VERSION into .venv ..."
	python3 -m venv .venv
	.venv/bin/pip install -q "gdtoolkit==$GDTOOLKIT_VERSION"
fi

if ! grep -qs "version=\"$GUT_VERSION\"" addons/gut/plugin.cfg; then
	echo "WARNING: addons/gut is not GUT $GUT_VERSION (tools/versions.env)."
fi

if ! command -v "$GODOT" >/dev/null; then
	echo "WARNING: Godot not found. Install Godot $GODOT_VERSION and put it on PATH as 'godot' or set GODOT=/path/to/godot."
elif ! "$GODOT" --version | grep -q "^$GODOT_VERSION"; then
	echo "WARNING: $("$GODOT" --version) found, but the project pins Godot $GODOT_VERSION."
fi

chmod +x tools/*.sh
[ -d .claude/hooks ] && chmod +x .claude/hooks/*.sh
echo "Setup done. Run tools/check.sh to verify."
