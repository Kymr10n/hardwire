#!/usr/bin/env bash
# Installs or updates Hardwire on a Steam Deck and adds it to Steam as a non-Steam game.
# Run on the Deck in Desktop Mode, by double-clicking Hardwire-SteamDeck.desktop or with
#   curl -fsSL https://raw.githubusercontent.com/Kymr10n/hardwire/main/tools/steamdeck_install.sh | bash
# Downloads the latest GitHub release into ~/Games/hardwire, registers it with
# tools/steamdeck_shortcut.py (Steam is closed for that and started again) and carries an old
# save into the Hardwire save folder. Running it again updates the game.
set -euo pipefail

REPO="Kymr10n/hardwire"
RAW="https://raw.githubusercontent.com/$REPO/main"
NAME="Hardwire: Boot Sequence"
DIR="$HOME/Games/hardwire"
EXE="$DIR/hardwire.x86_64"
step="starting"

fail() {
	echo
	echo "Something went wrong while $step. Nothing is broken: you can run the installer again."
	echo "If it keeps failing, report it at https://github.com/$REPO/issues with the text above."
	read -rp "Press Enter to close. "
	exit 1
}
trap fail ERR

echo "== Hardwire for Steam Deck =="
if [ "${XDG_CURRENT_DESKTOP:-}" = "gamescope" ] || pgrep -x gamescope >/dev/null 2>&1; then
	echo "Please switch to Desktop Mode first (Steam button > Power > Switch to Desktop) and run this again."
	read -rp "Press Enter to close. "
	exit 1
fi
for tool in curl python3; do
	command -v "$tool" >/dev/null || { echo "$tool is missing; this script expects SteamOS."; exit 1; }
done

step="looking up the latest release"
echo "Looking up the latest release ..."
read -r tag url < <(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | python3 -c '
import json, sys
release = json.load(sys.stdin)
linux = [a for a in release["assets"] if a["name"].endswith("-linux-x86_64")]
if not linux:
    sys.exit("the latest release has no Linux build")
print(release["tag_name"], linux[0]["browser_download_url"])')
mkdir -p "$DIR"

step="downloading the game"
if [ -s "$EXE" ] && [ "$(cat "$DIR/VERSION" 2>/dev/null)" = "$tag" ]; then
	echo "Hardwire $tag is already installed; checking the Steam entry."
else
	echo "Downloading Hardwire $tag (about 70 MB) ..."
	curl -fL --progress-bar -o "$EXE.part" "$url"
	mv "$EXE.part" "$EXE"
	chmod +x "$EXE"
	echo "$tag" >"$DIR/VERSION"
fi
curl -fsSL -o "$DIR/icon.png" "$RAW/docs/icon.png"
curl -fsSL -o "$DIR/steamdeck_shortcut.py" "$RAW/tools/steamdeck_shortcut.py"

step="adding the game to Steam"
was_running=0
if pgrep -x steam >/dev/null; then
	was_running=1
	echo "Closing Steam for a moment (it must not be running while the library is edited) ..."
	steam -shutdown >/dev/null 2>&1 || true
	for _ in $(seq 1 30); do
		pgrep -x steam >/dev/null || break
		sleep 1
	done
	pgrep -x steam >/dev/null && { echo "Steam did not close; close it yourself and run this again."; exit 1; }
fi
python3 "$DIR/steamdeck_shortcut.py" --exe "$EXE" --name "$NAME" --icon "$DIR/icon.png"
if [ "$was_running" -eq 1 ]; then
	echo "Starting Steam again ..."
	nohup steam >/dev/null 2>&1 &
fi

step="carrying over an old save"
old_save="$HOME/.local/share/godot/app_userdata/Hardwire/save.json"
new_dir="$HOME/.local/share/Hardwire"
if [ -f "$old_save" ] && [ ! -f "$new_dir/save.json" ]; then
	mkdir -p "$new_dir"
	cp -n "$old_save" "$new_dir/save.json"
	echo "Your save from the 0.1.0 prototype was carried over."
fi

echo
echo "Done: Hardwire $tag is in your Steam library under Non-Steam games."
echo "Switch to Game Mode and press Play. Run this installer again whenever you want to update."
read -rp "Press Enter to close. "
