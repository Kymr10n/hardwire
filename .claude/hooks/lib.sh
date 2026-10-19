#!/usr/bin/env bash
# Shared helpers for hook scripts. Hooks receive the event JSON on stdin.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
INPUT="$(cat)"

# The hooks guard files and run the gate; without python3 they cannot, so block (exit 2) rather
# than let an edit or an unchecked turn through. A Stop re-run (stop_hook_active) passes, so
# Claude reports the problem instead of looping.
if ! command -v python3 >/dev/null; then
	echo "hooks need python3 on PATH (see tools/setup.sh)" >&2
	grep -q '"stop_hook_active": *true' <<<"$INPUT" && exit 0
	exit 2
fi

# json_get <dotted.key> — read a field from the hook input (python3 avoids a jq dependency).
# The JSON goes in on stdin: a large Write would not fit on the command line.
json_get() {
	python3 -c 'import json,sys
v=json.load(sys.stdin)
for k in sys.argv[1].split("."): v=v.get(k,"") if isinstance(v,dict) else ""
print(v)' "$1" <<<"$INPUT"
}

# rel_path — the edited file relative to the project root.
rel_path() {
	local p
	p="$(json_get tool_input.file_path)"
	echo "${p#"$PWD"/}"
}
