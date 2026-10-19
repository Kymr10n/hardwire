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

if [ "$file" = "docs/DECISIONS.md" ] && [ "$(json_get tool_name)" = "Edit" ]; then
	old="$(json_get tool_input.old_string)"
	if [ -n "$old" ] && grep -qF -- "$old" <(git show HEAD:docs/DECISIONS.md 2>/dev/null); then
		echo "Blocked: docs/DECISIONS.md is append-only. Add a new entry that supersedes the old one." >&2
		exit 2
	fi
fi
exit 0
