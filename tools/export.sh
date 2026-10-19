#!/usr/bin/env bash
# Exports one preset from export_presets.cfg (needs the matching export templates).
# Usage: tools/export.sh <preset> <output path>   (GODOT=/path/to/godot to override the binary)
set -euo pipefail

GODOT="${GODOT:-godot}"
preset="$1"
output="$2"
cd "$(dirname "$0")/.." || exit 1

mkdir -p "$(dirname "$output")"
# Keep Godot from importing (and packing) its own export output.
touch build/.gdignore
# Import first so a fresh checkout has its resources ready (errors here are re-checked below).
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "$preset" "$output"
test -s "$output"
echo "Exported $preset to $output"
