#!/usr/bin/env bash
# Runs the GUT suite headless and fails on test failures AND on scripts GUT skipped
# (GUT exits 0 when a test script has a parse error). Used locally and by CI.
# Usage: tools/run_tests.sh   (GODOT=/path/to/godot to override the binary)
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 1
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# Import twice: the first pass can report errors for resources that reference
# files imported later in the same pass (for example the theme font).
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --import >"$log" 2>&1
if grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
	cat "$log"
	echo "::error::Script errors during import"
	exit 1
fi

"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tee "$log"
status=${PIPESTATUS[0]}

if [ "$status" -ne 0 ]; then
	echo "::error::GUT reported failing tests (exit $status)"
	exit "$status"
fi
if grep -qE "SCRIPT ERROR|Ignoring script" "$log"; then
	echo "::error::A test script failed to load and was skipped"
	exit 1
fi
if ! grep -q "All tests passed" "$log"; then
	echo "::error::GUT did not report 'All tests passed'"
	exit 1
fi
echo "Tests OK"
