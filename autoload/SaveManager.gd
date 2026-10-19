extends Node
## Loads and saves user://save.json (SPEC: Save system).
## Atomic write: write save.tmp.json, then rename over save.json.
## Broken or unknown files are backed up as save.bak.json and the game starts fresh.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Overridable so tests can use their own file. Temp and backup paths derive from it.
var save_path: String = SAVE_PATH


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func tmp_path() -> String:
	return save_path.get_basename() + ".tmp.json"


func backup_path() -> String:
	return save_path.get_basename() + ".bak.json"


## Writes GameState atomically. Returns false if the file could not be written.
func save_game() -> bool:
	GameState.last_seen = int(Time.get_unix_time_from_system())
	var d: Dictionary = GameState.to_dict()
	d["version"] = SAVE_VERSION
	var file := FileAccess.open(tmp_path(), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write %s (%s)" % [tmp_path(), error_string(FileAccess.get_open_error())])
		return false
	var ok: bool = file.store_string(JSON.stringify(d, "\t"))
	file.close()
	if not ok:
		push_error("SaveManager: write to %s failed" % tmp_path())
		return false
	var err := DirAccess.rename_absolute(tmp_path(), save_path)
	if err != OK:
		push_error("SaveManager: cannot rename %s to %s (%s)" % [tmp_path(), save_path, error_string(err)])
		return false
	return true


## Loads the save into GameState. Returns true if a valid save was loaded.
## A missing file means a fresh start; a broken or unknown file is backed up first.
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		GameState.reset_all()
		return false
	var json := JSON.new()
	var parsed: Variant = null
	if json.parse(FileAccess.get_file_as_string(save_path)) == OK:
		parsed = json.data
	if not (parsed is Dictionary) or not _is_known_version(parsed.get("version")):
		push_warning("SaveManager: %s is broken or has an unknown version; backing up to %s" % [save_path, backup_path()])
		_backup()
		GameState.reset_all()
		return false
	GameState.from_dict(parsed)
	return true


static func _is_known_version(value: Variant) -> bool:
	return (value is float or value is int) and int(value) == SAVE_VERSION


func _backup() -> void:
	if FileAccess.file_exists(backup_path()):
		DirAccess.remove_absolute(backup_path())
	var err := DirAccess.rename_absolute(save_path, backup_path())
	if err != OK:
		push_error("SaveManager: cannot back up %s (%s)" % [save_path, error_string(err)])
