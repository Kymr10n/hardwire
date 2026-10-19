#!/usr/bin/env python3
"""Adds or updates a non-Steam game in Steam's shortcuts.vdf (used by tools/steamdeck_install.sh).

Usage: steamdeck_shortcut.py --exe <path> --name <name> [--icon <path>] [--dry-run]

Steam must not be running while this writes: the client rewrites shortcuts.vdf when it exits.
Stdlib only. Binary VDF: \\x00 key\\x00 -> map ... \\x08, \\x01 key\\x00 -> string\\x00,
\\x02 key\\x00 -> int32 little-endian. Everything already in the file is written back byte for byte.
"""
import argparse
import glob
import os
import struct
import sys
import zlib

MAP, STRING, INT, END = 0, 1, 2, 8
ENCODING = ("utf-8", "surrogateescape")  # round-trips bytes Steam did not write as UTF-8


def parse_map(data, pos):
    out = {}
    while True:
        kind = data[pos]
        pos += 1
        if kind == END:
            return out, pos
        end = data.index(b"\x00", pos)
        key = data[pos:end].decode(*ENCODING)
        pos = end + 1
        if kind == MAP:
            out[key], pos = parse_map(data, pos)
        elif kind == STRING:
            end = data.index(b"\x00", pos)
            out[key] = data[pos:end].decode(*ENCODING)
            pos = end + 1
        elif kind == INT:
            out[key] = struct.unpack_from("<I", data, pos)[0]
            pos += 4
        else:
            raise ValueError(f"unknown VDF type {kind} at byte {pos - 1}")


def dump_map(mapping):
    out = bytearray()
    for key, value in mapping.items():
        name = key.encode(*ENCODING) + b"\x00"
        if isinstance(value, dict):
            out += bytes([MAP]) + name + dump_map(value)
        elif isinstance(value, str):
            out += bytes([STRING]) + name + value.encode(*ENCODING) + b"\x00"
        else:
            out += bytes([INT]) + name + struct.pack("<I", value)
    out += bytes([END])
    return bytes(out)


def steam_config_dir():
    """The config folder of the Steam user who played last (newest localconfig.vdf)."""
    pattern = "steam/userdata/*/config/localconfig.vdf"
    candidates = glob.glob(os.path.expanduser("~/.steam/" + pattern)) + glob.glob(
        os.path.expanduser("~/.local/share/Steam/userdata/*/config/localconfig.vdf")
    )
    if not candidates:
        sys.exit("No Steam user found (log in to Steam once, then run this again).")
    return os.path.dirname(max(candidates, key=os.path.getmtime))


def shortcut_appid(exe, name):
    """Steam's id for a non-Steam game: CRC32 of exe + name with the top bit set."""
    return (zlib.crc32((exe + name).encode("utf-8")) | 0x80000000) & 0xFFFFFFFF


def find_entry(shortcuts, exe):
    for index, entry in shortcuts.items():
        for key, value in entry.items():
            if key.lower() == "exe" and value.strip('"') == exe:
                return index, entry
    return None, None


def main():
    args = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    args.add_argument("--exe", required=True, help="path of the game binary")
    args.add_argument("--name", required=True, help="name shown in Steam")
    args.add_argument("--icon", default="", help="png shown in the library")
    args.add_argument("--dry-run", action="store_true", help="print the entry, write nothing")
    opts = args.parse_args()
    exe = os.path.abspath(opts.exe)
    icon = os.path.abspath(opts.icon) if opts.icon else ""

    config = steam_config_dir()
    path = os.path.join(config, "shortcuts.vdf")
    data = open(path, "rb").read() if os.path.exists(path) else dump_map({"shortcuts": {}})
    root, consumed = parse_map(data, 0)
    if consumed != len(data) or dump_map(root) != data:
        sys.exit(f"{path} is not in a form this script understands; nothing written.")
    shortcuts = root.setdefault("shortcuts", {})

    index, entry = find_entry(shortcuts, exe)
    if entry is None:
        index = str(len(shortcuts))
        entry = {
            "appid": shortcut_appid(f'"{exe}"', opts.name),
            "AppName": opts.name,
            "Exe": f'"{exe}"',
            "StartDir": f'"{os.path.dirname(exe)}/"',
            "icon": icon,
            "ShortcutPath": "",
            "LaunchOptions": "",
            "IsHidden": 0,
            "AllowDesktopConfig": 1,
            "AllowOverlay": 1,
            "OpenVR": 0,
            "Devkit": 0,
            "DevkitGameID": "",
            "DevkitOverrideAppID": 0,
            "LastPlayTime": 0,
            "FlatpakAppID": "",
            "tags": {},
        }
        shortcuts[index] = entry
        action = "added"
    else:
        for key in list(entry):
            if key.lower() == "appname":
                entry[key] = opts.name
            elif key.lower() == "icon" and icon:
                entry[key] = icon
        action = "updated"

    if opts.dry_run:
        print(f"would have {action} shortcut {index} in {path}:")
        for key, value in entry.items():
            print(f"  {key} = {value!r}")
        return
    with open(path, "wb") as f:
        f.write(dump_map(root))
    print(f"{action} '{opts.name}' in Steam ({path}).")


if __name__ == "__main__":
    main()
