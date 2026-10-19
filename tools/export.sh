#!/usr/bin/env bash
# Exports one preset from export_presets.cfg (needs the matching export templates).
# Usage: tools/export.sh <preset> <output path>   (GODOT=/path/to/godot to override the binary)
# The output path is relative to the repository root.
set -euo pipefail

[ $# -eq 2 ] || { echo "Usage: tools/export.sh <preset> <output path>" >&2; exit 2; }
GODOT="${GODOT:-godot}"
preset="$1"
output="$2"
cd "$(dirname "$0")/.." || exit 1

mkdir -p build "$(dirname "$output")"
# Keep Godot from importing (and packing) its own export output.
touch build/.gdignore
# Import first so a fresh checkout has its resources ready (script errors are tools/check.sh's job).
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "$preset" "$output"
test -s "$output"
echo "Exported $preset to $output"
