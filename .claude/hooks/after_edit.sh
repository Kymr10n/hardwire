#!/usr/bin/env bash
# PostToolUse(Write|Edit): auto-format and lint GDScript, validate JSON, flag spec edits without a decision.
source "$(dirname "$0")/lib.sh"
file="$(rel_path)"
PATH="$PWD/.venv/bin:$PATH"

case "$file" in
*.gd)
	if ! command -v gdformat >/dev/null; then
		echo "gdformat is not installed: run tools/setup.sh (installs gdtoolkit into .venv)." >&2
		exit 2
	fi
	if ! out="$(gdformat "$file" 2>&1)"; then
		echo "$out" >&2
		echo "gdformat could not parse $file — fix the syntax." >&2
		exit 2
	fi
	if ! out="$(gdlint "$file" 2>&1)"; then
		echo "$out" >&2
		echo "Fix these lint errors in $file (limits are in gdlintrc)." >&2
		exit 2
	fi
	;;
*.json)
	if ! out="$(python3 -m json.tool "$file" 2>&1 >/dev/null)"; then
		echo "Invalid JSON in $file: $out" >&2
		exit 2
	fi
	;;
docs/SPEC.md)
	if ! git status --porcelain -- docs/DECISIONS.md | grep -q .; then
		echo "docs/SPEC.md changed: add a D-NNN entry to docs/DECISIONS.md and update balance.json and tests in the same change (see /spec-change)." >&2
		exit 2
	fi
	;;
esac
exit 0
