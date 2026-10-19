extends GutTest
## balance.json loads and contains every section and key the spec relies on.

const REQUIRED := {
	"flow": ["countdown_s", "fail_reveal_s", "reward_countup_s", "locked_tiers_visible"],
	"economy": ["req_factor", "req_exponent", "reward_offset", "cycles_per_tier", "first_solve_mult",
		"modifier_mult", "core_bonus", "prestige_min_tier", "prestige_core_offset"],
	"idle": ["replays_per_hour", "cap_hours", "min_away_minutes"],
	"storage": ["length_base", "length_tier_divisor", "length_max", "show_ms_start", "show_ms_step",
		"show_ms_min", "gap_ms", "input_s_per_item_start", "input_s_per_item_step", "input_s_per_item_min"],
	"ram": ["filled_base", "filled_tier_divisor", "filled_max_ratio", "show_ms_start", "show_ms_step",
		"show_ms_min", "input_s_base", "input_s_per_cell"],
	"cpu": ["beats_base", "beats_tier_divisor", "beats_max", "on_steps_min", "on_steps_max",
		"off_steps_min", "off_steps_max", "step_ms_start", "step_ms_step", "step_ms_min",
		"tolerance_start", "tolerance_step", "tolerance_min", "tolerance_abs_ms", "end_grace_ms",
		"first_press_timeout_s"],
	"modifiers": ["from_tier", "second_pool_from_tier", "chance_base", "chance_step", "chance_max"],
	"debug": ["cycles_step", "panel_taps", "panel_tap_window_s"],
}

const UPGRADES: Array[String] = ["replay_buffer", "longer_exposure", "metronome", "time_dilation",
	"overclock", "cycle_miner"]


func test_balance_loaded() -> void:
	assert_false(Balance.data.is_empty(), "balance.json should load")


func test_required_numbers_exist() -> void:
	for section_name: String in REQUIRED:
		var section: Dictionary = Balance.section(section_name)
		for key: String in REQUIRED[section_name]:
			var value: Variant = section.get(key)
			assert_true(value is float or value is int, "%s.%s should be a number" % [section_name, key])


func test_tier_tables_exist() -> void:
	assert_eq(Balance.storage().get("pads_by_tier", []).size(), 4)
	assert_eq(Balance.ram().get("grid_by_tier", []).size(), 4)


func test_modifier_pools() -> void:
	var pools: Dictionary = Balance.modifiers().get("pools", {})
	for type: String in ["sto", "ram", "cpu"]:
		assert_eq(pools.get(type, []).size(), 2, "%s should have two modifiers" % type)


func test_upgrade_ids_match_spec() -> void:
	assert_eq(Balance.upgrade_ids(), UPGRADES)
	for id: String in UPGRADES:
		var u: Dictionary = Balance.upgrade(id)
		for key: String in ["max_level", "base_cost", "growth", "effect_per_level"]:
			assert_true(u.has(key), "%s.%s should exist" % [id, key])


func test_get_num_reads_values() -> void:
	assert_eq(Balance.get_num("cpu", "tolerance_start"), 0.30)
	assert_eq(Balance.get_int("economy", "cycles_per_tier"), 5)
