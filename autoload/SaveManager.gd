extends Node
## Loads and saves user://save.json (SPEC: Save system).
## Atomic write: write save.tmp.json, then rename over save.json.
## Broken or unknown files are backed up as save.bak.json and the game starts fresh.

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.tmp.json"
const BACKUP_PATH := "user://save.bak.json"
const SAVE_VERSION := 1


func save_game() -> void:
	pass # TODO(M1)


func load_game() -> void:
	pass # TODO(M1)
