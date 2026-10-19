#!/usr/bin/env bash
# Stop: before Claude finishes a turn that changed project files, the full quality gate must pass.
source "$(dirname "$0")/lib.sh"

# Already continuing because of this hook: don't loop forever; Claude must report the failure instead.
[ "$(json_get stop_hook_active)" = "True" ] && exit 0

# Nothing relevant changed (pure conversation): skip the gate.
if git rev-parse --git-dir >/dev/null 2>&1; then
	git status --porcelain -- autoload logic scenes tests data docs theme project.godot \
		export_presets.cfg gdlintrc tools |
		grep -q . || exit 0
fi

if ! out="$(tools/check.sh 2>&1)"; then
	{
		echo "tools/check.sh failed. Fix the problems below before finishing (do not weaken tests or limits):"
		echo "$out" | grep -v "^ok "
	} >&2
	exit 2
fi
exit 0
