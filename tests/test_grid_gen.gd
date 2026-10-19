extends GutTest
## GridGen against SPEC: Sample tiers table (RAM grid · filled · show ms) and modifier rules.

# tier: [n, filled, show_ms]
const SAMPLE_TIERS := {
	1: [3, 3, 2500],
	2: [3, 3, 2400],
	3: [3, 4, 2300],
	5: [4, 5, 2100],
	10: [5, 7, 1600],
	20: [6, 12, 1000],
}


func _make(tier: int, modifier: String, seed: int) -> Dictionary:
	return GridGen.make(SlotDef.create(tier, SlotDef.TYPE_RAM, modifier), seed)


func test_params_match_sample_tiers() -> void:
	for tier: int in SAMPLE_TIERS:
		var p: Dictionary = GridGen.params(tier)
		assert_eq([p.n, p.filled, p.show_ms], SAMPLE_TIERS[tier], "tier %d" % tier)


func test_grid_size_boundaries() -> void:
	var expected := {4: 3, 5: 4, 9: 4, 10: 5, 15: 5, 16: 6, 99: 6}
	for tier: int in expected:
		assert_eq(GridGen.params(tier).n, expected[tier], "tier %d" % tier)


func test_filled_is_capped_at_45_percent() -> void:
	# Tier 4 would want 4 cells on a 3x3 grid: floor(0.45 * 9) = 4.
	assert_eq(GridGen.params(4).filled, 4)
	# Tier 99 on 6x6: floor(0.45 * 36) = 16.
	assert_eq(GridGen.params(99).filled, 16)
	assert_eq(GridGen.params(99).show_ms, 1000)


func test_time_limit() -> void:
	assert_almost_eq(_make(1, "", 1).time_limit_s, 4.0 + 0.8 * 3, 0.0001)
	assert_almost_eq(_make(20, "", 1).time_limit_s, 4.0 + 0.8 * 12, 0.0001)
	# Inverted on tier 1: 9 - 3 = 6 cells needed.
	assert_almost_eq(_make(1, GridGen.MOD_INVERTED, 1).time_limit_s, 4.0 + 0.8 * 6, 0.0001)


func test_pattern_shape() -> void:
	for tier: int in SAMPLE_TIERS:
		for seed: int in 20:
			var a: Dictionary = _make(tier, "", seed)
			var pattern: Array[int] = a.pattern
			assert_eq(pattern.size(), SAMPLE_TIERS[tier][1])
			var unique := {}
			for i: int in pattern:
				assert_between(i, 0, a.n * a.n - 1)
				unique[i] = true
			assert_eq(unique.size(), pattern.size(), "no duplicate cells")
			var sorted: Array[int] = pattern.duplicate()
			sorted.sort()
			assert_eq(pattern, sorted)
			assert_eq(a.expected, pattern)


func test_same_seed_same_pattern() -> void:
	assert_eq(_make(10, "", 9).pattern, _make(10, "", 9).pattern)


func test_different_seeds_differ() -> void:
	var seen := {}
	for seed: int in 20:
		seen[str(_make(20, "", seed).pattern)] = true
	assert_gt(seen.size(), 15)


func test_every_cell_can_be_chosen() -> void:
	var hits := {}
	for seed: int in 200:
		for i: int in _make(1, "", seed).pattern:
			hits[i] = true
	assert_eq(hits.size(), 9)


func test_inverted_is_complement() -> void:
	var a: Dictionary = _make(10, GridGen.MOD_INVERTED, 3)
	assert_eq(a.expected.size(), 25 - 7)
	for i: int in 25:
		assert_ne(a.pattern.has(i), a.expected.has(i), "cell %d" % i)


func test_rotate_cw_3x3() -> void:
	# 0 1 2      6 3 0
	# 3 4 5  ->  7 4 1
	# 6 7 8      8 5 2
	# The cell at (r, c) moves to (c, n - 1 - r).
	var moved: Array[int] = []
	for i: int in 9:
		moved.append(GridGen.rotate_cw(i, 3))
	assert_eq(moved, [2, 5, 8, 1, 4, 7, 0, 3, 6] as Array[int])


func test_rotate_four_times_is_identity() -> void:
	for n: int in [3, 4, 5, 6]:
		for i: int in n * n:
			var j: int = i
			for k: int in 4:
				j = GridGen.rotate_cw(j, n)
			assert_eq(j, i)


func test_rotated_expected() -> void:
	var a: Dictionary = _make(5, GridGen.MOD_ROTATED, 4)
	var rotated: Array[int] = []
	for i: int in a.pattern:
		rotated.append(GridGen.rotate_cw(i, a.n))
	rotated.sort()
	assert_eq(a.expected, rotated)
	assert_eq(a.time_limit_s, _make(5, "", 4).time_limit_s)
