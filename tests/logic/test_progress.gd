extends GutTest
## Progress: gating, tiers, rebuild eligibility and idle offers.
## SPEC: Stats, currency and slot gating; Prestige; Idle income.

const NOW := 1_800_000_000
const SOLVED_T1: Array[String] = ["1:ram"]


func _stats(ram: int, cpu: int, sto: int) -> Dictionary:
	return {"ram": ram, "cpu": cpu, "sto": sto}


func test_every_stat_must_meet_requirement() -> void:
	var req: Dictionary = SlotGenerator.make(3, SlotDef.TYPE_RAM).req
	assert_false(Progress.is_unlocked(req, _stats(8, 4, 8)))
	assert_eq(Progress.missing(req, _stats(8, 4, 8)), {"cpu": 4})
	assert_true(Progress.is_unlocked(req, _stats(8, 8, 8)))
	assert_eq(Progress.missing(req, _stats(8, 8, 8)), {})


func test_highest_unlocked_tier() -> void:
	assert_eq(Progress.highest_unlocked_tier(_stats(0, 0, 0)), 1)
	assert_eq(Progress.highest_unlocked_tier(_stats(162, 162, 162)), 10)
	assert_eq(Progress.highest_unlocked_tier(_stats(162, 161, 162)), 9, "the lowest stat decides")


func test_tier_leds_show_progress_to_the_next_tier() -> void:
	assert_eq(Progress.tier_leds(0, 1, 10), 0, "tier 1 needs 0, tier 2 needs 2")
	assert_eq(Progress.tier_leds(1, 1, 10), 5)
	assert_eq(Progress.tier_leds(2, 1, 10), 10)
	assert_eq(Progress.tier_leds(11, 3, 10), 3, "tier 3 needs 8, tier 4 needs 18")
	assert_eq(Progress.tier_leds(99, 3, 10), 10, "never past the bank")


func test_highest_solved_tier() -> void:
	assert_eq(Progress.highest_solved_tier([] as Array[String]), 0)
	assert_eq(Progress.highest_solved_tier(["3:ram", "7:cpu", "2:sto"] as Array[String]), 7)


func test_rebuild_needs_tier_10() -> void:
	assert_false(Progress.can_rebuild(["9:ram"] as Array[String]))
	assert_true(Progress.can_rebuild(["10:cpu"] as Array[String]))
	assert_eq(Progress.rebuild_cores(["20:sto", "12:ram"] as Array[String]), 11)


func test_idle_offer_needs_more_than_5_minutes() -> void:
	assert_eq(Progress.idle_offer(NOW - 300, NOW, SOLVED_T1, 0, 0), 0)
	assert_gt(Progress.idle_offer(NOW - 301, NOW, SOLVED_T1, 0, 0), 0)


func test_idle_offer_amount() -> void:
	# t_max 1: 6 x cycles(1) = 30 Cycles per hour; Overclock is not an input.
	assert_eq(Progress.idle_offer(NOW - 3600, NOW, SOLVED_T1, 0, 0), 30)


func test_idle_clock_edge_cases() -> void:
	assert_eq(Progress.seconds_away(0, NOW), 0, "missing last_seen")
	assert_eq(Progress.seconds_away(NOW + 1000, NOW), 0, "clock went backwards")
	assert_eq(Progress.idle_offer(NOW + 1000, NOW, SOLVED_T1, 0, 0), 0)
