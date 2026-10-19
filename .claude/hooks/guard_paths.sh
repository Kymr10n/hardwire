#!/usr/bin/env bash
# PreToolUse(Write|Edit): block edits to generated or vendored files and to past decisions.
source "$(dirname "$0")/lib.sh"
file="$(rel_path)"

case "$file" in
.godot/* | addons/* | .venv/*)
	echo "Blocked: $file is generated or vendored. Change the source instead (GUT in addons/ is pinned in tools/versions.env)." >&2
	exit 2
	;;
esac

# docs/DECISIONS.md is append-only: the committed text must stay a prefix of the edited file.
APPEND_ONLY=$(cat <<'PY'
import json, sys
event = json.load(sys.stdin)
path, head = sys.argv[1], sys.argv[2].rstrip()
tool, args = event.get("tool_name"), event.get("tool_input", {})
if tool == "Write":
    result = args.get("content", "")
else:
    current = open(path, encoding="utf-8").read()
    old, new = args.get("old_string", ""), args.get("new_string", "")
    result = current.replace(old, new) if args.get("replace_all") else current.replace(old, new, 1)
sys.exit(0 if result.rstrip().startswith(head) else 1)
PY
)
if [ "$file" = "docs/DECISIONS.md" ] && head="$(git show HEAD:docs/DECISIONS.md 2>/dev/null)"; then
	if ! python3 -c "$APPEND_ONLY" "$file" "$head" <<<"$INPUT"; then
		echo "Blocked: docs/DECISIONS.md is append-only. Keep every committed entry and add a new one that supersedes the old." >&2
		exit 2
	fi
fi
exit 0
