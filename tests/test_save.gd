extends GutTest
## GameState serialization and SaveManager atomic save/load, backup on broken files.
## Uses its own save file and restores GameState, so the real save is never touched.

const TEST_PATH := "user://test_save.json"

var _orig_path: String
var _orig_state: Dictionary


func before_each() -> void:
	_orig_path = SaveManager.save_path
	_orig_state = GameState.to_dict()
	SaveManager.save_path = TEST_PATH
	_remove_test_files()
	GameState.reset_all()


func after_each() -> void:
	_remove_test_files()
	SaveManager.save_path = _orig_path
	GameState.from_dict(_orig_state)


func _remove_test_files() -> void:
	for path: String in [SaveManager.save_path, SaveManager.tmp_path(), SaveManager.backup_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _fill_state() -> void:
	GameState.add_stats(3, 5, 7)
	GameState.cycles = 120
	GameState.cores = 2
	GameState.upgrades["metronome"] = 3
	GameState.solved_slots = ["1:ram", "1:cpu"] as Array[String]
	GameState.best_tier_ever = 4
	GameState.seen_tutorials = ["sto"] as Array[String]
	GameState.settings["sound"] = false
	GameState.lifetime["solves"] = 9


func test_fresh_state_has_all_upgrades_at_zero() -> void:
	assert_eq(GameState.upgrades.size(), 6)
	for id: String in Balance.upgrade_ids():
		assert_eq(GameState.upgrades[id], 0)


func test_to_dict_matches_save_schema() -> void:
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = ["best_tier_ever", "cores", "cycles", "last_seen", "lifetime", "seen_tutorials",
		"settings", "solved_slots", "stats", "upgrades"]
	assert_eq(keys, expected)


func test_dict_roundtrip() -> void:
	_fill_state()
	var d: Dictionary = GameState.to_dict()
	GameState.reset_all()
	GameState.from_dict(d)
	assert_eq(GameState.to_dict(), d)


func test_from_dict_survives_json_floats() -> void:
	_fill_state()
	var d: Variant = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.reset_all()
	GameState.from_dict(d)
	assert_eq(GameState.ram, 3)
	assert_eq(GameState.cpu, 5)
	assert_eq(GameState.sto, 7)
	assert_typeof(GameState.cycles, TYPE_INT)
	assert_eq(GameState.upgrades["metronome"], 3)


func test_from_dict_fills_missing_fields() -> void:
	GameState.from_dict({"stats": {"ram": 4}, "upgrades": {"bogus": 9}, "settings": {"sound": "no"}})
	assert_eq(GameState.ram, 4)
	assert_eq(GameState.cpu, 0)
	assert_false(GameState.upgrades.has("bogus"))
	assert_eq(GameState.upgrades.size(), 6)
	assert_true(GameState.settings["sound"])
	assert_eq(GameState.lifetime["rebuilds"], 0)


func test_save_then_load_restores_state() -> void:
	_fill_state()
	assert_true(SaveManager.save_game())
	var saved: Dictionary = GameState.to_dict()
	GameState.reset_all()
	assert_true(SaveManager.load_game())
	assert_eq(GameState.to_dict(), saved)


func test_save_is_atomic_and_versioned() -> void:
	assert_true(SaveManager.save_game())
	assert_false(FileAccess.file_exists(SaveManager.tmp_path()), "temp file should be renamed away")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	assert_eq(int(d["version"]), SaveManager.SAVE_VERSION)
	assert_gt(int(d["last_seen"]), 0)


func test_save_overwrites_existing_file() -> void:
	GameState.add_stats(1, 1, 1)
	SaveManager.save_game()
	GameState.add_stats(1, 1, 1)
	SaveManager.save_game()
	GameState.reset_all()
	SaveManager.load_game()
	assert_eq(GameState.ram, 2)


func test_missing_file_starts_fresh() -> void:
	GameState.add_stats(5, 5, 5)
	assert_false(SaveManager.load_game())
	assert_eq(GameState.ram, 0)
	assert_false(FileAccess.file_exists(SaveManager.backup_path()))


func test_corrupt_file_is_backed_up() -> void:
	_write("{ not json")
	GameState.add_stats(5, 5, 5)
	assert_false(SaveManager.load_game())
	assert_eq(GameState.ram, 0)
	assert_false(FileAccess.file_exists(TEST_PATH))
	assert_eq(FileAccess.get_file_as_string(SaveManager.backup_path()), "{ not json")


func test_unknown_version_is_backed_up() -> void:
	_write('{"version": 99, "stats": {"ram": 50, "cpu": 0, "sto": 0}}')
	assert_false(SaveManager.load_game())
	assert_eq(GameState.ram, 0)
	assert_true(FileAccess.file_exists(SaveManager.backup_path()))


func test_non_object_json_is_backed_up() -> void:
	_write("[1, 2, 3]")
	assert_false(SaveManager.load_game())
	assert_true(FileAccess.file_exists(SaveManager.backup_path()))
