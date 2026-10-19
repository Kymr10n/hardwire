#!/usr/bin/env bash
# Shared helpers for hook scripts. Hooks receive the event JSON on stdin.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
INPUT="$(cat)"

# json_get <dotted.key> — read a field from the hook input (python3 avoids a jq dependency).
json_get() {
	python3 -c 'import json,sys
v=json.loads(sys.argv[1])
for k in sys.argv[2].split("."): v=v.get(k,"") if isinstance(v,dict) else ""
print(v)' "$INPUT" "$1"
}

# rel_path — the edited file relative to the project root.
rel_path() {
	local p
	p="$(json_get tool_input.file_path)"
	echo "${p#"$PWD"/}"
}
