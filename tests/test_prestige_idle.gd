extends "res://tests/hardwire_test.gd"
## Prestige ("Rebuild") and idle income (SPEC: Prestige, Idle income; M7 Done-when).

const Main := preload("res://scenes/Main.tscn")
const NOW := 1_800_000_000


func _solve(tier: int, type: String) -> void:
	GameState.apply_solve(SlotGenerator.make(tier, type))


func test_cores_for() -> void:
	assert_eq(Economy.cores_for(9), 0)
	assert_eq(Economy.cores_for(10), 1)
	assert_eq(Economy.cores_for(20), 11)


func test_rebuild_needs_tier_10_solve() -> void:
	set_stats(722)
	_solve(9, SlotDef.TYPE_RAM)
	assert_false(GameState.can_rebuild())
	assert_eq(GameState.rebuild(), 0)
	_solve(10, SlotDef.TYPE_CPU)
	assert_true(GameState.can_rebuild())


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


func test_idle_cycles_formula() -> void:
	# t_max 10: 6 x 50 = 300 Cycles per hour.
	assert_eq(Economy.idle_cycles(3600, 10, 0, 0), 300)
	assert_eq(Economy.idle_cycles(1800, 10, 0, 0), 150)
	assert_eq(Economy.idle_cycles(8 * 3600, 10, 0, 0), 2400)
	assert_eq(Economy.idle_cycles(30 * 3600, 10, 0, 0), 2400, "capped at 8 h")
	# Cycle miner 2 (+20%) and 2 Cores (x1.5): 300 x 1.2 x 1.5 = 540
	assert_eq(Economy.idle_cycles(3600, 10, 2, 2), 540)
	assert_eq(Economy.idle_cycles(3600, 0, 0, 0), 0, "nothing before the first solve")
	assert_eq(Economy.idle_cycles(-500, 10, 0, 0), 0)


func test_idle_ignores_overclock() -> void:
	GameState.upgrades.overclock = 5
	_solve(1, SlotDef.TYPE_RAM)
	GameState.last_seen = NOW - 3600
	assert_eq(GameState.idle_offer(NOW), 6 * 5)


func test_idle_offer_needs_more_than_5_minutes() -> void:
	_solve(1, SlotDef.TYPE_RAM)
	GameState.last_seen = NOW - 300
	assert_eq(GameState.idle_offer(NOW), 0)
	GameState.last_seen = NOW - 301
	assert_gt(GameState.idle_offer(NOW), 0)


func test_idle_clock_edge_cases() -> void:
	_solve(1, SlotDef.TYPE_RAM)
	GameState.last_seen = 0
	assert_eq(GameState.seconds_away(NOW), 0, "missing last_seen")
	GameState.last_seen = NOW + 1000
	assert_eq(GameState.seconds_away(NOW), 0, "clock went backwards")
	assert_eq(GameState.idle_offer(NOW), 0)


func test_last_seen_survives_save_and_drives_offer() -> void:
	set_stats(8)
	_solve(3, SlotDef.TYPE_RAM)
	SaveManager.save_game()
	var saved: int = GameState.last_seen
	GameState.reset_all()
	SaveManager.load_game()
	assert_eq(GameState.last_seen, saved)
	# 2 hours later: 6 x cycles(3) x 2 = 180
	assert_eq(GameState.idle_offer(saved + 7200), 180)


func _main() -> Node:
	var main: Node = Main.instantiate()
	add_child_autofree(main)
	return main


func _dialogs(node: Node) -> Array[Node]:
	return node.find_children("*", "ConfirmDialog", true, false)


func test_idle_dialog_collects() -> void:
	_solve(5, SlotDef.TYPE_RAM)
	GameState.last_seen = int(Time.get_unix_time_from_system()) - 2 * 3600
	var main := _main()
	main.show_overview()
	var dialogs := _dialogs(main)
	assert_eq(dialogs.size(), 1, "While you were away")
	var before: int = GameState.cycles
	dialogs[0]._close(true)
	# t_max 5: 6 x 25 x 2 h = 300
	assert_eq(GameState.cycles - before, 300)
	assert_true(FileAccess.file_exists(TEST_SAVE))
	main.show_overview()
	assert_eq(_dialogs(main.screen).size(), 0, "offered once per start")


func test_no_idle_dialog_without_solve() -> void:
	GameState.last_seen = int(Time.get_unix_time_from_system()) - 2 * 3600
	var main := _main()
	main.show_overview()
	assert_eq(_dialogs(main).size(), 0)


func test_rebuild_dialog_flow() -> void:
	set_stats(162)
	_solve(10, SlotDef.TYPE_RAM)
	var main := _main()
	main._idle_check_pending = false
	main.show_overview()
	assert_false(main.screen.rebuild_button.disabled)
	main.show_rebuild_dialog()
	var dialogs := _dialogs(main)
	assert_eq(dialogs.size(), 1)
	dialogs[0]._close(true)
	assert_eq(GameState.cores, 1)
	assert_eq(GameState.ram, 0)
	assert_true(main.screen.rebuild_button.disabled, "fresh overview after the reset")
