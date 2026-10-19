extends GutTest
## Base for tests that touch GameState or screens: snapshots and restores GameState, redirects
## saves to a test file and mutes sound, so the real save is never touched.
## Not collected itself (no test_ prefix); tests extend it by path.

const TEST_SAVE := "user://test_save.json"
const FRAME := 1.0 / 60.0

var _orig_path: String
var _orig_state: Dictionary
var _orig_time_scale: float


func before_each() -> void:
	_orig_path = SaveManager.save_path
	_orig_state = GameState.to_dict()
	_orig_time_scale = Engine.time_scale
	SaveManager.save_path = TEST_SAVE
	_remove_test_files()
	GameState.reset_all()
	GameState.settings.sound = false
	GameState.settings.haptics = false
	# First-run hints hold the first attempt; tests that check hints clear this.
	GameState.seen_tutorials = [SlotDef.TYPE_STO, SlotDef.TYPE_RAM, SlotDef.TYPE_CPU] as Array[String]


func after_each() -> void:
	_remove_test_files()
	SaveManager.save_path = _orig_path
	GameState.from_dict(_orig_state)
	Engine.time_scale = _orig_time_scale


func _remove_test_files() -> void:
	for path: String in [SaveManager.save_path, SaveManager.tmp_path(), SaveManager.backup_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Sets all three stats to `value`.
func set_stats(value: int) -> void:
	GameState.add_stats(value - GameState.ram, value - GameState.cpu, value - GameState.sto)
