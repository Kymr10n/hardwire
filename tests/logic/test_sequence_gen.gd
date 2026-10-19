extends GutTest
## SequenceGen against SPEC: Sample tiers table (Storage length · pads · show ms) and modifier
## rules.

# tier: [length, pads, show_ms]
const SAMPLE_TIERS := {
	1: [3, 4, 700],
	2: [4, 4, 675],
	3: [4, 4, 650],
	5: [5, 5, 600],
	10: [8, 6, 475],
	20: [12, 8, 300],
}


func _make(tier: int, modifier: String, seed: int) -> Dictionary:
	return SequenceGen.make(SlotDef.create(tier, SlotDef.TYPE_STO, modifier), seed)


func test_params_match_sample_tiers() -> void:
	for tier: int in SAMPLE_TIERS:
		var p: Dictionary = SequenceGen.params(tier)
		var row: Array = SAMPLE_TIERS[tier]
		assert_eq([p.length, p.pads, p.show_ms], row, "tier %d" % tier)


func test_pad_count_boundaries() -> void:
	var expected := {3: 4, 4: 5, 7: 5, 8: 6, 12: 6, 13: 8, 50: 8}
	for tier: int in expected:
		assert_eq(SequenceGen.params(tier).pads, expected[tier], "tier %d" % tier)


func test_length_and_show_ms_clamp() -> void:
	assert_eq(SequenceGen.params(100).length, 12)
	assert_eq(SequenceGen.params(100).show_ms, 300)


func test_input_time_per_item() -> void:
	assert_almost_eq(SequenceGen.params(1).input_s_per_item, 1.5, 0.0001)
	assert_almost_eq(SequenceGen.params(11).input_s_per_item, 1.2, 0.0001)
	assert_almost_eq(SequenceGen.params(50).input_s_per_item, 0.8, 0.0001)
	assert_almost_eq(_make(1, "", 1).time_limit_s, 3 * 1.5, 0.0001)
	assert_almost_eq(_make(20, "", 1).time_limit_s, 12 * 0.93, 0.0001)


func test_gap_is_150_ms() -> void:
	assert_eq(_make(5, "", 1).gap_ms, 150)


func test_sequence_shape() -> void:
	for tier: int in SAMPLE_TIERS:
		for seed: int in 20:
			var a: Dictionary = _make(tier, "", seed)
			assert_eq(a.sequence.size(), SAMPLE_TIERS[tier][0])
			for pad: int in a.sequence:
				assert_between(pad, 0, a.pads - 1)
			assert_eq(a.expected, a.sequence)
			assert_eq(a.playback.size(), a.sequence.size())


func test_same_seed_same_sequence() -> void:
	assert_eq(_make(10, "", 42).sequence, _make(10, "", 42).sequence)


func test_different_seeds_differ() -> void:
	var seen := {}
	for seed: int in 20:
		seen[str(_make(20, "", seed).sequence)] = true
	assert_gt(seen.size(), 15, "20 seeds should give (nearly) 20 different sequences")


func test_reverse_expects_back_to_front() -> void:
	for seed: int in 10:
		var a: Dictionary = _make(8, SequenceGen.MOD_REVERSE, seed)
		var reversed: Array[int] = a.sequence.duplicate()
		reversed.reverse()
		assert_eq(a.expected, reversed)
		assert_eq(a.playback.size(), a.sequence.size(), "reverse adds no playback items")


func test_decoy_inserted_between_real_items() -> void:
	for tier: int in [1, 8, 20]:
		for seed: int in 50:
			var a: Dictionary = _make(tier, SequenceGen.MOD_DECOY, seed)
			var playback: Array[Dictionary] = a.playback
			assert_eq(playback.size(), a.sequence.size() + 1)
			var decoys: Array[int] = []
			var real: Array[int] = []
			for i: int in playback.size():
				if playback[i].decoy:
					decoys.append(i)
				else:
					real.append(playback[i].pad)
			assert_eq(decoys.size(), 1)
			var at: int = decoys[0]
			assert_between(at, 1, playback.size() - 2, "never first or last")
			var pad: int = playback[at].pad
			assert_ne(pad, playback[at - 1].pad)
			assert_ne(pad, playback[at + 1].pad)
			assert_eq(real, a.sequence, "real items keep their order")
			assert_eq(a.expected, a.sequence, "decoy is not part of the answer")


func test_tier_table_lookup() -> void:
	assert_eq(Balance.tier_table("ram", "grid_by_tier", 4), 3)
	assert_eq(Balance.tier_table("ram", "grid_by_tier", 5), 4)
	assert_eq(Balance.tier_table("ram", "grid_by_tier", 16), 6)
