#!/usr/bin/env bash
# Exports the Linux and Windows builds and uploads them with SteamPipe (SPEC: Steam release).
# The build is not set live: pick it in Steamworks → Builds and set it on a branch by hand.
# Usage: tools/steam_upload.sh [--preview]
#   --preview  let SteamPipe build the manifests and report sizes without uploading
# Uploads only from a clean, committed tree, so the build description names the exact commit.
# Settings come from tools/steam.local.env (git-ignored; it overrides the environment), e.g.
#   STEAM_APP_ID=1234560
#   STEAM_DEPOT_LINUX=1234561
#   STEAM_DEPOT_WINDOWS=1234562
#   STEAM_USER=my_builder_account
# Needs steamcmd on PATH; the first login asks for the Steam Guard code.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

preview=0
for arg in "$@"; do
	case "$arg" in
	--preview) preview=1 ;;
	*) echo "Unknown option: $arg (use --preview)" >&2 && exit 2 ;;
	esac
done

# shellcheck source=/dev/null
[ -f tools/steam.local.env ] && source tools/steam.local.env
: "${STEAM_APP_ID:?set STEAM_APP_ID (tools/steam.local.env)}"
: "${STEAM_DEPOT_LINUX:?set STEAM_DEPOT_LINUX (tools/steam.local.env)}"
: "${STEAM_DEPOT_WINDOWS:?set STEAM_DEPOT_WINDOWS (tools/steam.local.env)}"
: "${STEAM_USER:?set STEAM_USER (tools/steam.local.env)}"
command -v steamcmd >/dev/null || { echo "steamcmd not found (install it from Valve)" >&2 && exit 1; }
if [ "$preview" -eq 0 ] && ! git diff --quiet HEAD; then
	echo "Uncommitted changes: commit first, or use --preview." >&2 && exit 1
fi

tools/export.sh Linux build/linux/hardwire.x86_64
tools/export.sh Windows build/windows/hardwire.exe

steam="$PWD/build/steam"
mkdir -p "$steam/output"
version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
# One file per depot: nothing else left in build/ can slip into a release.
depot() { # depot <id> <file under build/>
	printf '\t\t"%s" { "FileMapping" { "LocalPath" "%s" "DepotPath" "." } }\n' "$1" "$2"
}
cat >"$steam/app_build.vdf" <<EOF
"AppBuild"
{
	"AppID" "$STEAM_APP_ID"
	"Desc" "$version ($(git describe --always --dirty))"
	"Preview" "$preview"
	"ContentRoot" "$PWD/build"
	"BuildOutput" "$steam/output"
	"Depots"
	{
$(depot "$STEAM_DEPOT_LINUX" linux/hardwire.x86_64)
$(depot "$STEAM_DEPOT_WINDOWS" windows/hardwire.exe)
	}
}
EOF

# steamcmd can exit 0 after a failed login or build, so check its output too.
steamcmd +login "$STEAM_USER" +run_app_build "$steam/app_build.vdf" +quit | tee "$steam/steamcmd.log"
grep -q "Successfully finished AppID $STEAM_APP_ID" "$steam/steamcmd.log" ||
	{ echo "SteamPipe did not report success; see build/steam/steamcmd.log." >&2 && exit 1; }
