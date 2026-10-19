extends GutTest
## SlotGenerator and Economy.solve_reward against SPEC: Sample tiers table and Modifiers.

# tier: [req, stat first, stat replay, cycles first, cycles replay]
const SAMPLE_TIERS := {
	1: [0, 4, 2, 10, 5],
	2: [2, 6, 3, 20, 10],
	3: [8, 8, 4, 30, 15],
	5: [32, 12, 6, 50, 25],
	10: [162, 22, 11, 100, 50],
	20: [722, 42, 21, 200, 100],
}


func _plain(tier: int, type: String) -> SlotDef:
	var slot: SlotDef = SlotGenerator.make(tier, type)
	slot.modifier = ""
	return slot


func test_formulas_match_sample_tiers() -> void:
	for tier: int in SAMPLE_TIERS:
		var row: Array = SAMPLE_TIERS[tier]
		for type: String in SlotGenerator.TYPES:
			var slot := _plain(tier, type)
			assert_eq(slot.req, {"ram": row[0], "cpu": row[0], "sto": row[0]}, "req tier %d" % tier)
			var first: Dictionary = Economy.solve_reward(slot, true, 0, 0, 0)
			var replay: Dictionary = Economy.solve_reward(slot, false, 0, 0, 0)
			assert_eq([first.stat, replay.stat, first.cycles, replay.cycles], row.slice(1), "rewards tier %d" % tier)


func test_tier_slots_order() -> void:
	var types: Array[String] = []
	for slot: SlotDef in SlotGenerator.tier_slots(4):
		types.append(slot.type)
		assert_eq(slot.tier, 4)
	assert_eq(types, [SlotDef.TYPE_RAM, SlotDef.TYPE_CPU, SlotDef.TYPE_STO] as Array[String])


func test_fnv1a_reference_values() -> void:
	assert_eq(SlotGenerator.fnv1a32(""), 0x811C9DC5)
	assert_eq(SlotGenerator.fnv1a32("a"), 0xE40C292C)
	assert_eq(SlotGenerator.fnv1a32("foobar"), 0xBF9CF968)


func test_modifiers_are_deterministic() -> void:
	for tier: int in range(1, 60):
		for type: String in SlotGenerator.TYPES:
			assert_eq(SlotGenerator.make(tier, type).modifier, SlotGenerator.make(tier, type).modifier)


func test_no_modifiers_before_tier_8() -> void:
	for tier: int in range(1, 8):
		for type: String in SlotGenerator.TYPES:
			assert_eq(SlotGenerator.make(tier, type).modifier, "")


func test_modifier_pools_by_tier() -> void:
	var pools: Dictionary = Balance.modifiers().pools
	var seen_second: bool = false
	for tier: int in range(8, 300):
		for type: String in SlotGenerator.TYPES:
			var mod: String = SlotGenerator.make(tier, type).modifier
			if mod.is_empty():
				continue
			if tier < 14:
				assert_eq(mod, pools[type][0], "tier %d %s uses the first modifier only" % [tier, type])
			else:
				assert_true(pools[type].has(mod))
				seen_second = seen_second or mod == pools[type][1]
	assert_true(seen_second, "second modifiers appear from tier 14")


func test_modifier_chance() -> void:
	assert_eq(SlotGenerator.modifier_chance(7), 0.0)
	assert_almost_eq(SlotGenerator.modifier_chance(8), 0.3, 0.0001)
	assert_almost_eq(SlotGenerator.modifier_chance(16), 0.5, 0.0001)
	assert_almost_eq(SlotGenerator.modifier_chance(100), 0.8, 0.0001)
	# Over many late tiers the hash should hit roughly 80%.
	var hits: int = 0
	var total: int = 0
	for tier: int in range(28, 1028):
		for type: String in SlotGenerator.TYPES:
			total += 1
			if not SlotGenerator.make(tier, type).modifier.is_empty():
				hits += 1
	assert_between(float(hits) / total, 0.75, 0.85)


func test_modifier_and_multipliers() -> void:
	var slot := _plain(9, SlotDef.TYPE_RAM)
	slot.modifier = "inverted"
	# reward 10, cycles 45: x1.5 modifier
	assert_eq(Economy.solve_reward(slot, false, 0, 0, 0), {"stat": 15, "cycles": 68})
	assert_eq(Economy.solve_reward(slot, true, 0, 0, 0), {"stat": 30, "cycles": 135})
	var plain := _plain(9, SlotDef.TYPE_RAM)
	# Overclock 2 (+20% stats), Cycle miner 3 (+30% Cycles), 2 Cores (x1.5)
	assert_eq(Economy.solve_reward(plain, false, 2, 3, 2), {"stat": 18, "cycles": 88})
	assert_almost_eq(Economy.core_multiplier(4), 2.0, 0.0001)
