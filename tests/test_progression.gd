extends "res://tests/hardwire_test.gd"
## GameState gating and solve crediting (SPEC: Stats, currency and slot gating; M5 Done-when).


func _solve(tier: int, type: String) -> Dictionary:
	return GameState.apply_solve(SlotGenerator.make(tier, type))


func test_fresh_save_reaches_tier_4_with_first_solves_only() -> void:
	assert_eq(Progress.highest_unlocked_tier(GameState.stats()), 1)
	for tier: int in range(1, 4):
		for slot: SlotDef in SlotGenerator.tier_slots(tier):
			assert_true(Progress.is_unlocked(slot.req, GameState.stats()), "tier %d open" % tier)
			GameState.apply_solve(slot)
	assert_eq(Progress.highest_unlocked_tier(GameState.stats()), 4)
	for slot: SlotDef in SlotGenerator.tier_slots(4):
		GameState.apply_solve(slot)
	assert_eq([GameState.ram, GameState.cpu, GameState.sto], [28, 28, 28])
	assert_eq(Progress.highest_unlocked_tier(GameState.stats()), 4, "tier 5 (32) needs replays")
	assert_false(
		Progress.is_unlocked(SlotGenerator.make(5, SlotDef.TYPE_CPU).req, GameState.stats())
	)


func test_first_solve_then_replay() -> void:
	var first: Dictionary = _solve(2, SlotDef.TYPE_STO)
	assert_eq(first, {"stat": 6, "cycles": 20, "first_solve": true, "new_tier": 0})
	var replay: Dictionary = _solve(2, SlotDef.TYPE_STO)
	assert_eq(replay.first_solve, false)
	assert_eq([GameState.sto, GameState.ram, GameState.cycles], [9, 0, 30])
	assert_eq(GameState.solved_slots, ["2:sto"] as Array[String])
	assert_eq(int(GameState.lifetime.solves), 2)
	assert_eq(GameState.best_tier_ever, 2)


func test_new_tier_is_reported() -> void:
	_solve(1, SlotDef.TYPE_RAM)
	_solve(1, SlotDef.TYPE_CPU)
	var last: Dictionary = _solve(1, SlotDef.TYPE_STO)
	assert_eq(last.new_tier, 2)


func test_rewards_use_upgrades_and_cores() -> void:
	GameState.upgrades.overclock = 1
	GameState.cores = 2
	# tier 1 first solve: 2 x 2 x 1.1 x 1.5 = 6.6 -> 7
	assert_eq(_solve(1, SlotDef.TYPE_RAM).stat, 7)


func test_fail_is_counted() -> void:
	GameState.record_fail()
	assert_eq(int(GameState.lifetime.fails), 1)


func test_solved_slots_survive_save() -> void:
	_solve(1, SlotDef.TYPE_RAM)
	SaveManager.save_game()
	GameState.reset_all()
	SaveManager.load_game()
	assert_true(GameState.is_solved(SlotGenerator.make(1, SlotDef.TYPE_RAM)))
