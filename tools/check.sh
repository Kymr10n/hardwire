#!/usr/bin/env bash
# The single quality gate. Used by the Claude Code Stop hook, CI and humans.
# Runs format, lint, drift checks, Godot import/boot (script errors) and GUT tests. Exit 1 on any failure.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
source tools/versions.env
GODOT="${GODOT:-godot}"
PATH="$PWD/.venv/bin:$PATH"
SRC=(autoload logic scenes tests)
failed=0

run() {
	local name="$1" out
	shift
	if out="$("$@" 2>&1)"; then
		echo "ok    $name"
	else
		echo "FAIL  $name"
		echo "$out" | tail -n 40 | sed 's/^/      /'
		failed=1
	fi
}

# Godot exits 0 even on script errors, so scan its output instead.
godot_clean() {
	local log
	log="$("$GODOT" --headless --path . "$@" 2>&1)"
	if grep -E "SCRIPT ERROR|Parse Error|Failed to load script|Compile Error" <<<"$log"; then
		return 1
	fi
}

# GUT exits 0 when a test script fails to parse (it just skips it), so check its output too.
gut_tests() {
	local log status
	log="$("$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
	status=${PIPESTATUS[0]}
	grep -E "^(Scripts|Tests|Passing Tests|Failing Tests) " <<<"$log"
	if [ "$status" -ne 0 ] || grep -qE "SCRIPT ERROR|Ignoring script" <<<"$log" || ! grep -q "All tests passed" <<<"$log"; then
		grep -E "\[Failed\]|SCRIPT ERROR|Ignoring script" -A2 <<<"$log" | head -n 40
		return 1
	fi
}

# A fresh checkout's first import can report errors for resources that reference files
# imported later in the same pass (the theme font), so import once quietly first.
"$GODOT" --headless --path . --import >/dev/null 2>&1

run "format (gdformat)" gdformat --check "${SRC[@]}"
run "lint (gdlint)" gdlint "${SRC[@]}"
run "drift" python3 tools/drift_check.py
run "import" godot_clean --import
run "boot" godot_clean --quit-after 30
run "tests (GUT)" gut_tests

[ "$failed" -eq 0 ] && echo "All checks passed." || echo "Checks failed."
exit "$failed"
