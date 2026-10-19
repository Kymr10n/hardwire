extends "res://tests/hardwire_test.gd"
## Prestige ("Rebuild") and idle income (SPEC: Prestige, Idle income; M7 Done-when).

const NOW := 1_800_000_000


func _solve(tier: int, type: String) -> void:
	GameState.apply_solve(SlotGenerator.make(tier, type))


func test_rebuild_needs_tier_10_solve() -> void:
	set_stats(722)
	_solve(9, SlotDef.TYPE_RAM)
	assert_false(Progress.can_rebuild(GameState.solved_slots))
	assert_eq(GameState.rebuild(), 0)
	_solve(10, SlotDef.TYPE_CPU)
	assert_true(Progress.can_rebuild(GameState.solved_slots))


func test_rebuild_resets_the_right_fields() -> void:
	set_stats(722)
	_solve(20, SlotDef.TYPE_STO)
	_solve(12, SlotDef.TYPE_RAM)
	GameState.cycles = 5000
	GameState.upgrades.overclock = 3
	GameState.upgrades.metronome = 2
	GameState.cores = 1
	GameState.seen_tutorials = ["ram"] as Array[String]
	GameState.settings.sound = true
	GameState.lifetime.fails = 4
	var gained: int = GameState.rebuild()
	assert_eq(gained, 11)
	assert_eq(GameState.cores, 12)
	assert_eq([GameState.ram, GameState.cpu, GameState.sto, GameState.cycles], [0, 0, 0, 0])
	for id: String in Balance.upgrade_ids():
		assert_eq(GameState.upgrade_level(id), 0, id)
	assert_eq(GameState.solved_slots, [] as Array[String])
	assert_eq(GameState.best_tier_ever, 20, "kept")
	assert_eq(GameState.seen_tutorials, ["ram"] as Array[String], "kept")
	assert_true(GameState.settings.sound, "kept")
	assert_eq(int(GameState.lifetime.fails), 4, "kept")
	assert_eq(int(GameState.lifetime.solves), 2, "kept")
	assert_eq(int(GameState.lifetime.rebuilds), 1)


func test_core_multiplier_applies_after_rebuild() -> void:
	set_stats(162)
	_solve(10, SlotDef.TYPE_RAM)
	GameState.rebuild()
	assert_almost_eq(Economy.core_multiplier(GameState.cores), 1.25, 0.0001)
	# tier 1 first solve: 4 x 1.25 = 5; cycles 10 x 1.25 = 12.5 -> 13
	var gain: Dictionary = GameState.apply_solve(SlotGenerator.make(1, SlotDef.TYPE_RAM))
	assert_eq([gain.stat, gain.cycles], [5, 13])


func test_last_seen_survives_save_and_drives_offer() -> void:
	set_stats(8)
	_solve(3, SlotDef.TYPE_RAM)
	SaveManager.save_game()
	var saved: int = GameState.last_seen
	GameState.reset_all()
	SaveManager.load_game()
	assert_eq(GameState.last_seen, saved)
	# 2 hours later: 6 x cycles(3) x 2 = 180
	assert_eq(
		Progress.idle_offer(GameState.last_seen, saved + 7200, GameState.solved_slots, 0, 0), 180
	)


func _dialogs(node: Node) -> Array[Node]:
	return node.find_children("*", "ConfirmDialog", true, false)


func test_idle_dialog_collects() -> void:
	_solve(5, SlotDef.TYPE_RAM)
	GameState.last_seen = int(Time.get_unix_time_from_system()) - 2 * 3600
	var main := make_main(true)
	main.show_overview()
	var dialogs := _dialogs(main)
	assert_eq(dialogs.size(), 1, "While you were away")
	main.show_overview()
	dialogs = _dialogs(main.screen)
	assert_eq(dialogs.size(), 1, "still offered: the screen was re-created before collecting")
	var before: int = GameState.cycles
	dialogs[0].confirm()
	# t_max 5: 6 x 25 x 2 h = 300
	assert_eq(GameState.cycles - before, 300)
	assert_true(FileAccess.file_exists(TEST_SAVE))
	main.show_overview()
	assert_eq(_dialogs(main.screen).size(), 0, "offered once per start")


func test_no_idle_dialog_without_solve() -> void:
	GameState.last_seen = int(Time.get_unix_time_from_system()) - 2 * 3600
	var main := make_main(true)
	main.show_overview()
	assert_eq(_dialogs(main).size(), 0)


func test_rebuild_dialog_flow() -> void:
	set_stats(162)
	_solve(10, SlotDef.TYPE_RAM)
	var main := make_main(true)
	main.show_overview()
	assert_false(main.screen.rebuild_button.disabled)
	main.screen.rebuild_button.pressed.emit()
	var dialogs := _dialogs(main)
	assert_eq(dialogs.size(), 1)
	dialogs[0].confirm()
	assert_eq(GameState.cores, 1)
	assert_eq(GameState.ram, 0)
	assert_true(main.screen.rebuild_button.disabled, "no tier 10 solve after the reset")
	assert_eq(main.screen.rows().size(), 3, "surplus tier rows removed")


func test_idle_dialog_waits_while_a_puzzle_is_open() -> void:
	_solve(5, SlotDef.TYPE_RAM)
	GameState.last_seen = int(Time.get_unix_time_from_system()) - 2 * 3600
	var main := make_main(true)
	main.show_puzzle(SlotGenerator.make(1, SlotDef.TYPE_STO))
	assert_eq(_dialogs(main.screen).size(), 0, "never over a running puzzle")
	main.show_overview()
	assert_eq(_dialogs(main.screen).size(), 1, "offered once back on the overview")
