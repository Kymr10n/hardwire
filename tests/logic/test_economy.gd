extends GutTest
## Economy: rewards and multipliers, upgrade costs and caps, prestige Cores, idle Cycles.
## SPEC: Difficulty curve > Economy formulas, Upgrade shop, Prestige, Idle income.


func _slot(tier: int, modifier: String) -> SlotDef:
	var slot: SlotDef = SlotGenerator.make(tier, SlotDef.TYPE_RAM)
	slot.modifier = modifier
	return slot


func test_modifier_and_multipliers() -> void:
	var slot := _slot(9, "inverted")
	# reward 10, cycles 45: x1.5 modifier
	assert_eq(Economy.solve_reward(slot, false, 0, 0, 0), {"stat": 15, "cycles": 68})
	assert_eq(Economy.solve_reward(slot, true, 0, 0, 0), {"stat": 30, "cycles": 135})
	# Overclock 2 (+20% stats), Cycle miner 3 (+30% Cycles), 2 Cores (x1.5)
	assert_eq(Economy.solve_reward(_slot(9, ""), false, 2, 3, 2), {"stat": 18, "cycles": 88})
	assert_almost_eq(Economy.core_multiplier(4), 2.0, 0.0001)


func test_upgrade_costs() -> void:
	var expected := {
		"replay_buffer": [50, 150],
		"longer_exposure": [30, 54, 97, 175, 315],
		"metronome": [30, 54, 97, 175, 315],
		"time_dilation": [40, 76, 144, 274, 521],
		"overclock": [100, 220, 484, 1065],
		"cycle_miner": [80, 160, 320, 640],
	}
	for id: String in expected:
		for level: int in expected[id].size():
			assert_eq(Economy.upgrade_cost(id, level), expected[id][level], "%s %d" % [id, level])


func test_upgrade_caps() -> void:
	assert_true(Economy.is_maxed("replay_buffer", 2))
	assert_false(Economy.is_maxed("replay_buffer", 1))
	assert_true(Economy.is_maxed("metronome", 5))
	assert_false(Economy.is_maxed("overclock", 1000), "economy upgrades are uncapped")


func test_can_buy() -> void:
	assert_true(Economy.can_buy("metronome", 0, 30))
	assert_false(Economy.can_buy("metronome", 0, 29), "too expensive")
	assert_false(Economy.can_buy("replay_buffer", 2, 100_000), "maxed")


func test_cores_for() -> void:
	assert_eq(Economy.cores_for(9), 0)
	assert_eq(Economy.cores_for(10), 1)
	assert_eq(Economy.cores_for(20), 11)


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
