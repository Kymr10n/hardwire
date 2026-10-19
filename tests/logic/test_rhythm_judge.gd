extends GutTest
## RhythmJudge: the pure function that decides whether the CPU minigame feels fair (SPEC: Judging).

const TOL := 0.30
const ABS := 60.0
# on 300, off 300, on 600, off 300, on 300 (tier 1 steps: 1, 1, 2, 1, 1 at 300 ms)
const TARGET: Array[float] = [300.0, 300.0, 600.0, 300.0, 300.0]


## Builds press/release timestamps (usec) from segment lengths (ms), starting at `start_usec`.
func _input_from(segments: Array, start_usec: int = 5_000_000) -> Array:
	var presses: Array[int] = []
	var releases: Array[int] = []
	var t: float = start_usec
	for i: int in segments.size():
		if i % 2 == 0:
			presses.append(int(t))
		else:
			pass
		t += float(segments[i]) * 1000.0
		if i % 2 == 0:
			releases.append(int(t))
	return [presses, releases]


func _judge(segments: Array, target: Array[float] = TARGET) -> Dictionary:
	var io: Array = _input_from(segments)
	return RhythmJudge.judge(io[0], io[1], target, TOL, ABS)


func test_exact_input_passes() -> void:
	var r: Dictionary = _judge(TARGET)
	assert_true(r.passed)
	assert_eq(r.reason, "")
	assert_eq(r.ok, [true, true, true, true, true] as Array[bool])


func test_start_time_is_irrelevant() -> void:
	var io: Array = _input_from(TARGET, 123_456_789)
	assert_true(RhythmJudge.judge(io[0], io[1], TARGET, TOL, ABS).passed)


func test_within_tolerance_passes() -> void:
	# 30% of 300 = 90, of 600 = 180.
	assert_true(_judge([389, 211, 780, 300, 211]).passed)


func test_at_tolerance_edge_passes() -> void:
	assert_true(_judge([390, 210, 420, 390, 300]).passed)


func test_one_segment_out_of_tolerance_fails() -> void:
	var r: Dictionary = _judge([300, 300, 790, 300, 300])
	assert_false(r.passed)
	assert_eq(r.reason, "timing")
	assert_eq(r.ok, [true, true, false, true, true] as Array[bool])
	assert_almost_eq(r.actual_ms[2], 790.0, 0.01)


func test_too_many_presses_fails() -> void:
	var r: Dictionary = _judge([300, 300, 600, 300, 300, 300, 300])
	assert_false(r.passed)
	assert_eq(r.reason, "count")


func test_too_few_presses_fails() -> void:
	var r: Dictionary = _judge([300, 300, 600])
	assert_false(r.passed)
	assert_eq(r.reason, "count")


func test_missing_release_fails() -> void:
	var io: Array = _input_from(TARGET)
	var releases: Array[int] = io[1]
	releases.pop_back()
	var r: Dictionary = RhythmJudge.judge(io[0], releases, TARGET, TOL, ABS)
	assert_false(r.passed)
	assert_eq(r.reason, "unreleased")


func test_absolute_floor_for_short_segments() -> void:
	# 100 ms target: 30% would be 30 ms, but the floor is 60 ms.
	var target: Array[float] = [100.0, 100.0, 100.0]
	assert_true(_judge([160, 40, 100], target).passed)
	assert_false(_judge([161, 100, 100], target).passed)


func test_uniformly_slow_within_tolerance_passes() -> void:
	# Every segment 25% long: total drifts by 25% but each segment is fine.
	assert_true(_judge([375, 375, 750, 375, 375]).passed)


func test_allowance_and_max_total() -> void:
	assert_eq(RhythmJudge.allowance(100.0, TOL, ABS), 60.0)
	assert_almost_eq(RhythmJudge.allowance(600.0, TOL, ABS), 180.0, 0.001)
	# 300+90, 300+90, 600+180, 300+90, 300+90
	assert_almost_eq(RhythmJudge.max_total_ms(TARGET, TOL, ABS), 2340.0, 0.001)
