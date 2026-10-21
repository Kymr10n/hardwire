extends GutTest
## balance.json loads and contains every section and key the spec relies on.

const REQUIRED := {
	"flow": ["countdown_s", "fail_reveal_s", "reward_countup_s", "locked_tiers_visible"],
	"economy":
	[
		"req_factor",
		"req_exponent",
		"reward_offset",
		"cycles_per_tier",
		"first_solve_mult",
		"modifier_mult",
		"core_bonus",
		"prestige_min_tier",
		"prestige_core_offset"
	],
	"idle": ["replays_per_hour", "cap_hours", "min_away_minutes"],
	"audio":
	[
		"key_hz",
		"key_ms",
		"key_volume",
		"relay_hz",
		"relay_end_hz",
		"relay_ms",
		"relay_volume",
		"tick_hz",
		"tick_ms",
		"tick_volume",
		"click_volume",
		"boot_from_hz",
		"boot_to_hz",
		"boot_ms",
		"boot_volume",
		"boot_noise_volume",
		"hum_volume",
		"hum_cutoff_hz",
		"hum_attack_ms"
	],
	"storage":
	[
		"length_base",
		"length_tier_divisor",
		"length_max",
		"show_ms_start",
		"show_ms_step",
		"show_ms_min",
		"gap_ms",
		"input_s_per_item_start",
		"input_s_per_item_step",
		"input_s_per_item_min"
	],
	"ram":
	[
		"filled_base",
		"filled_tier_divisor",
		"filled_max_ratio",
		"show_ms_start",
		"show_ms_step",
		"show_ms_min",
		"input_s_base",
		"input_s_per_cell"
	],
	"cpu":
	[
		"beats_base",
		"beats_tier_divisor",
		"beats_max",
		"on_steps_min",
		"on_steps_max",
		"off_steps_min",
		"off_steps_max",
		"step_ms_start",
		"step_ms_step",
		"step_ms_min",
		"tolerance_start",
		"tolerance_step",
		"tolerance_min",
		"tolerance_abs_ms",
		"first_press_timeout_s"
	],
	"modifiers": ["from_tier", "second_pool_from_tier", "chance_base", "chance_step", "chance_max"],
	"debug": ["cycles_step", "panel_taps", "panel_tap_window_s"],
	"haptics":
	[
		"pulse_ms",
		"pulse_strength",
		"hold_strength",
		"decoy_strength",
		"success_pulse_ms",
		"success_gap_ms",
		"fail_pulse_ms"
	],
}

const UPGRADES: Array[String] = [
	"replay_buffer", "longer_exposure", "metronome", "time_dilation", "overclock", "cycle_miner"
]


func test_balance_loaded() -> void:
	assert_false(Balance.data.is_empty(), "balance.json should load")


func test_required_numbers_exist() -> void:
	for section_name: String in REQUIRED:
		var section: Dictionary = Balance.section(section_name)
		for key: String in REQUIRED[section_name]:
			var value: Variant = section.get(key)
			assert_true(
				value is float or value is int, "%s.%s should be a number" % [section_name, key]
			)


func test_tier_tables_exist() -> void:
	assert_eq(Balance.section("storage").get("pads_by_tier", []).size(), 4)
	assert_eq(Balance.section("ram").get("grid_by_tier", []).size(), 4)


func test_modifier_pools() -> void:
	var pools: Dictionary = Balance.section("modifiers").get("pools", {})
	for type: String in ["sto", "ram", "cpu"]:
		assert_eq(pools.get(type, []).size(), 2, "%s should have two modifiers" % type)


func test_upgrade_ids_match_spec() -> void:
	assert_eq(Balance.upgrade_ids(), UPGRADES)
	for id: String in UPGRADES:
		var u: Dictionary = Balance.upgrade(id)
		for key: String in ["max_level", "base_cost", "growth", "effect_per_level"]:
			assert_true(u.has(key), "%s.%s should exist" % [id, key])


func test_get_num_reads_values() -> void:
	assert_eq(Balance.get_num("cpu", "tolerance_start"), 0.40)
	assert_eq(Balance.get_int("economy", "cycles_per_tier"), 5)


## The numbers the spec states, so a balance edit cannot drift from docs/SPEC.md unnoticed.
func test_spec_numbers() -> void:
	var spec := {
		"flow": {"countdown_s": 1.5, "fail_reveal_s": 1.0, "reward_countup_s": 0.6},
		"economy": {"first_solve_mult": 2.0, "modifier_mult": 1.5, "core_bonus": 0.25},
		"idle": {"replays_per_hour": 6, "cap_hours": 8, "min_away_minutes": 5},
		"storage": {"gap_ms": 150, "show_ms_min": 300, "length_max": 12},
		"ram": {"show_ms_min": 1000, "input_s_base": 4.0, "input_s_per_cell": 0.8},
		"cpu": {"tolerance_abs_ms": 100, "first_press_timeout_s": 5.0},
		"modifiers": {"from_tier": 8, "second_pool_from_tier": 14, "chance_max": 0.8},
	}
	for section: String in spec:
		for key: String in spec[section]:
			assert_eq(
				Balance.get_num(section, key), float(spec[section][key]), "%s.%s" % [section, key]
			)
