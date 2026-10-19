#!/usr/bin/env bash
# Exports the Linux build and copies it to a Steam Deck over SSH (setup: README, Steam Deck).
# Usage: tools/deck.sh   (DECK=user@host to override the target, default deck@steamdeck)
set -euo pipefail

DECK="${DECK:-deck@steamdeck}"
cd "$(dirname "$0")/.." || exit 1

tools/export.sh Linux build/linux/hardwire.x86_64
ssh "$DECK" 'mkdir -p ~/Games/hardwire'
# A fixed path keeps the Steam "Non-Steam Game" shortcut valid; rsync sends only changed blocks.
rsync -z --progress build/linux/hardwire.x86_64 "$DECK:Games/hardwire/"
echo "Deployed to $DECK:~/Games/hardwire, press Play in game mode"
