extends GutTest
## RhythmGen against SPEC: Sample tiers table (CPU beats · step ms · tolerance) and the rhythm
## model.

# tier: [beats, step_ms, tolerance]
const SAMPLE_TIERS := {
	1: [3, 300, 0.30],
	2: [3, 292, 0.2925],
	3: [4, 284, 0.285],
	5: [4, 268, 0.27],
	10: [6, 228, 0.2325],
	20: [9, 150, 0.1575],
}


func _make(tier: int, modifier: String, seed: int) -> Dictionary:
	return RhythmGen.make(SlotDef.create(tier, SlotDef.TYPE_CPU, modifier), seed)


func test_params_match_sample_tiers() -> void:
	for tier: int in SAMPLE_TIERS:
		var p: Dictionary = RhythmGen.params(tier)
		var row: Array = SAMPLE_TIERS[tier]
		assert_eq(p.beats, row[0], "beats tier %d" % tier)
		assert_eq(p.step_ms, row[1], "step tier %d" % tier)
		assert_almost_eq(p.tolerance, row[2], 0.00001, "tolerance tier %d" % tier)


func test_caps() -> void:
	var p: Dictionary = RhythmGen.params(200)
	assert_eq(p.beats, 10)
	assert_eq(p.step_ms, 150)
	assert_almost_eq(p.tolerance, 0.15, 0.00001)


func test_rhythm_model() -> void:
	for tier: int in SAMPLE_TIERS:
		for seed: int in 30:
			var a: Dictionary = _make(tier, "", seed)
			var steps: Array[float] = a.steps
			assert_eq(
				steps.size(),
				a.beats * 2 - 1,
				"no off-segment before the first or after the last beat"
			)
			for i: int in steps.size():
				assert_eq(steps[i], roundf(steps[i]), "whole steps without Syncopated")
				if i % 2 == 0:
					assert_between(steps[i], 1.0, 3.0, "on-segment")
				else:
					assert_between(steps[i], 1.0, 2.0, "off-segment")
				assert_almost_eq(a.target_ms[i], steps[i] * a.step_ms, 0.001)


func test_holds_and_taps_both_occur() -> void:
	var seen := {}
	for seed: int in 50:
		for i: int in range(0, _make(10, "", seed).steps.size(), 2):
			seen[_make(10, "", seed).steps[i]] = true
	assert_eq(seen.size(), 3, "on-segments use 1, 2 and 3 steps")


func test_totals() -> void:
	var a: Dictionary = _make(5, "", 3)
	var total: float = 0.0
	for t: float in a.target_ms:
		total += t
	assert_almost_eq(a.total_ms, total, 0.001)
	assert_gt(a.max_total_ms, a.total_ms, "the input window allows the tolerance on top")
	assert_eq(a.abs_ms, 60.0)


func test_deterministic() -> void:
	assert_eq(_make(10, "", 77).steps, _make(10, "", 77).steps)


func test_syncopated_has_half_steps() -> void:
	for seed: int in 50:
		var a: Dictionary = _make(14, RhythmGen.MOD_SYNCOPATED, seed)
		var halves: int = 0
		for s: float in a.steps:
			if not is_equal_approx(s, roundf(s)):
				halves += 1
				assert_true(is_equal_approx(s, 0.5) or is_equal_approx(s, 1.5))
		assert_gt(halves, 0, "seed %d" % seed)


func test_audio_only_keeps_rhythm() -> void:
	assert_eq(_make(9, RhythmGen.MOD_AUDIO_ONLY, 4).steps, _make(9, "", 4).steps)
