#!/usr/bin/env bash
# Exports the Linux build and copies it to a Steam Deck over SSH (setup: README, Steam Deck).
# A fixed path keeps the Steam "Non-Steam Game" shortcut valid; rsync sends only changed blocks.
# Usage: tools/deck.sh [--no-export] [--run]
#   --no-export  copy the existing build/linux/hardwire.x86_64 instead of exporting first
#   --run        start the game on the Deck afterwards (Desktop Mode; Game Mode starts it from Steam)
# The Deck's address comes from $DECK or tools/deck.local.env (git-ignored), e.g.
#   DECK=deck@steamdeck.local
# Needs SSH access to the Deck (Desktop Mode: set a password with `passwd`, enable sshd).
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
# shellcheck source=/dev/null
[ -f tools/deck.local.env ] && source tools/deck.local.env
DECK="${DECK:-deck@steamdeck}"
DECK_DIR="${DECK_DIR:-Games/hardwire}" # relative to the Deck user's home
BUILD=build/linux/hardwire.x86_64

export_build=1
run=0
for arg in "$@"; do
	case "$arg" in
	--no-export) export_build=0 ;;
	--run) run=1 ;;
	*) echo "Unknown option: $arg (use --no-export, --run)" >&2 && exit 2 ;;
	esac
done

[ "$export_build" -eq 1 ] && tools/export.sh Linux "$BUILD"
[ -s "$BUILD" ] || { echo "No build at $BUILD; run without --no-export." >&2 && exit 1; }

echo "Deploying to $DECK:~/$DECK_DIR ..."
ssh "$DECK" "mkdir -p ~/'$DECK_DIR'"
rsync -az --chmod=u+x "$BUILD" "$DECK:$DECK_DIR/"

if [ "$run" -eq 1 ]; then
	ssh "$DECK" "pkill -x hardwire.x86_64 || true; cd ~/'$DECK_DIR' &&
		DISPLAY=:0 SteamDeck=1 nohup ./hardwire.x86_64 >/dev/null 2>&1 &"
	echo "Started on the Deck."
fi
echo "Deployed. In Steam (once): add /home/deck/$DECK_DIR/hardwire.x86_64 as a non-Steam game, then press Play in game mode."
