#!/usr/bin/env bash
# Stop: before Claude finishes a turn that changed project files, the full quality gate must pass.
source "$(dirname "$0")/lib.sh"

# Already continuing because of this hook: don't loop forever; Claude must report the failure instead.
[ "$(json_get stop_hook_active)" = "True" ] && exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
WATCHED=(autoload logic scenes tests data docs theme addons project.godot export_presets.cfg gdlintrc .gutconfig.json tools)

# Nothing relevant changed (pure conversation): skip the gate.
git status --porcelain -- "${WATCHED[@]}" | grep -q . || exit 0

# The same uncommitted state already passed the gate earlier: skip it too.
stamp=.godot/.gate_ok
state="$({ git status --porcelain -- "${WATCHED[@]}"; git diff HEAD -- "${WATCHED[@]}"; } | sha256sum | cut -c1-64)"
[ -f "$stamp" ] && [ "$(cat "$stamp")" = "$state" ] && exit 0

if ! out="$(tools/check.sh 2>&1)"; then
	{
		echo "tools/check.sh failed. Fix the problems below before finishing (do not weaken tests or limits):"
		echo "$out" | grep -v "^ok "
	} >&2
	exit 2
fi
mkdir -p .godot && echo "$state" >"$stamp"
exit 0
