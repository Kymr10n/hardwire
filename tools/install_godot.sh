#!/usr/bin/env bash
# Downloads Godot (Linux x86_64) and optionally the export templates, verifying both against
# the release's SHA512-SUMS.txt. Used by CI.
# Usage: tools/install_godot.sh <version> <dest_dir> [--templates]
set -euo pipefail

[ $# -ge 2 ] || { echo "Usage: tools/install_godot.sh <version> <dest_dir> [--templates]" >&2; exit 2; }
version="$1"
dest="$2"
base="https://github.com/godotengine/godot/releases/download/${version}-stable"
mkdir -p "$dest"
cd "$dest"

curl -fsSL -o SHA512-SUMS.txt "$base/SHA512-SUMS.txt"

fetch() {
	local name="$1"
	if [ ! -f "$name" ]; then
		curl -fsSL -o "$name" "$base/$name"
	fi
	grep " $name\$" SHA512-SUMS.txt | sha512sum -c -
}

editor="Godot_v${version}-stable_linux.x86_64"
fetch "${editor}.zip"
unzip -o -q "${editor}.zip"
ln -sf "$PWD/${editor}" "$PWD/godot"

if [ "${3:-}" = "--templates" ]; then
	templates="Godot_v${version}-stable_export_templates.tpz"
	fetch "$templates"
	target="$HOME/.local/share/godot/export_templates/${version}.stable"
	mkdir -p "$target"
	unzip -o -q "$templates" -d templates_tmp
	cp -r templates_tmp/templates/. "$target/"
	rm -rf templates_tmp
fi
