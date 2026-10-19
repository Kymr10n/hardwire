# gdlint: disable=max-public-methods
extends GutTest
## RhythmJudge: the pure function that decides whether the CPU minigame feels fair (SPEC: Judging).


## A rhythm as RhythmGen builds it.
func _rhythm(target: Array[float], step_ms: int = 300, tolerance: float = 0.3) -> Dictionary:
	return {"target_ms": target, "step_ms": step_ms, "tolerance": tolerance, "abs_ms": 100.0}


## tap 300, gap 300, hold 600, gap 300, tap 300 (tier 1 steps 1, 1, 2, 1, 1 at 300 ms), judged
## at 30% so the boundary numbers stay round (the judge takes the tolerance as data; the tier
## curve is tested in test_rhythm_gen): beat intervals 600 and 900; one hold (beat 1, 600 ms).
func _tier1() -> Dictionary:
	return _rhythm([300.0, 300.0, 600.0, 300.0, 300.0] as Array[float])


## Press/release timestamps (usec) from pressed lengths (ms) and press-to-press intervals (ms).
func _input_from(held: Array, intervals: Array, start_usec: int = 5_000_000) -> Array:
	var presses: Array[int] = []
	var releases: Array[int] = []
	var t: float = start_usec
	for i: int in held.size():
		presses.append(int(t))
		releases.append(int(t + float(held[i]) * 1000.0))
		if i < intervals.size():
			t += float(intervals[i]) * 1000.0
	return [presses, releases]


func _judge(held: Array, intervals: Array, rhythm: Dictionary = _tier1()) -> Dictionary:
	var io: Array = _input_from(held, intervals)
	return RhythmJudge.judge(io[0], io[1], rhythm)


func _misses(held: Array, intervals: Array, rhythm: Dictionary = _tier1()) -> Array[Dictionary]:
	var io: Array = _input_from(held, intervals)
	return RhythmJudge.misses(io[0], io[1], rhythm)


## {beat, kind} of each miss, without the delta.
func _where(misses: Array[Dictionary]) -> Array:
	var out: Array = []
	for m: Dictionary in misses:
		out.append([m.beat, m.kind])
	return out


func test_exact_input_passes() -> void:
	var r: Dictionary = _judge([300, 600, 300], [600, 900])
	assert_true(r.passed)
	assert_eq(r.reason, "")


func test_quick_taps_pass() -> void:
	# Play-test (D-022): a natural click lasts 100-150 ms; taps are not timed, only beats and holds.
	assert_true(_judge([100, 600, 100], [600, 900]).passed)
	assert_true(_judge([40, 600, 150], [600, 900]).passed)


func test_start_time_is_irrelevant() -> void:
	var io: Array = _input_from([300, 600, 300], [600, 900], 123_456_789)
	assert_true(RhythmJudge.judge(io[0], io[1], _tier1()).passed)


func test_beats_within_tolerance_pass() -> void:
	# 30% of 600 = 180, of 900 = 270.
	assert_true(_judge([300, 600, 300], [780, 630]).passed)
	assert_true(_judge([300, 600, 300], [420, 1170]).passed)


func test_beat_out_of_tolerance_fails() -> void:
	# The second interval is 300 ms long, so the third press (beat 2) came late.
	var r: Dictionary = _judge([300, 600, 300], [600, 1200])
	assert_false(r.passed)
	assert_eq(r.reason, "timing")
	assert_eq(_where(r.misses), [[2, "beat"]])
	assert_almost_eq(r.misses[0].delta_ms, 300.0, 0.001)


## Judged as you play (D-030): only the checks the input so far determines are made.
func test_misses_judge_partial_input() -> void:
	assert_eq(_misses([300, 600, 300], [600, 900]), [] as Array[Dictionary], "exact input")
	assert_eq(_misses([300], []), [] as Array[Dictionary], "one tap: nothing to check yet")
	var late: Array[Dictionary] = _misses([300, 600], [1200])
	assert_eq(_where(late), [[1, "beat"]], "second press late: reported on beat 1")
	assert_almost_eq(late[0].delta_ms, 600.0, 0.001)
	var early: Array[Dictionary] = _misses([300, 600], [300])
	assert_almost_eq(early[0].delta_ms, -300.0, 0.001, "early press: negative delta")
	var short: Array[Dictionary] = _misses([300, 200], [600])
	assert_eq(_where(short), [[1, "hold"]], "hold judged at its release")
	assert_almost_eq(short[0].delta_ms, -400.0, 0.001)


func test_hold_within_tolerance_passes() -> void:
	assert_true(_judge([300, 780, 300], [600, 900]).passed)
	assert_true(_judge([300, 420, 300], [600, 900]).passed)


func test_hold_outside_tolerance_fails() -> void:
	var short: Dictionary = _judge([300, 300, 300], [600, 900])
	assert_eq(_where(short.misses), [[1, "hold"]], "too short")
	var long: Dictionary = _judge([300, 781, 300], [600, 900])
	assert_eq(_where(long.misses), [[1, "hold"]], "too long, just past 600 + 180")


func test_last_beat_hold_is_judged() -> void:
	# The last beat has no interval check, so its hold check is all that judges it.
	var rhythm := _rhythm([300.0, 300.0, 600.0] as Array[float])
	assert_true(_judge([100, 600], [600], rhythm).passed)
	var r: Dictionary = _judge([100, 300], [600], rhythm)
	assert_false(r.passed)
	assert_eq(_where(r.misses), [[1, "hold"]])


func test_too_many_presses_fails() -> void:
	var r: Dictionary = _judge([300, 600, 300, 300], [600, 900, 600])
	assert_false(r.passed)
	assert_eq(r.reason, "count")


func test_too_few_presses_fails() -> void:
	var r: Dictionary = _judge([300, 600], [600])
	assert_false(r.passed)
	assert_eq(r.reason, "count")


func test_missing_release_fails() -> void:
	var io: Array = _input_from([300, 600, 300], [600, 900])
	var releases: Array[int] = io[1]
	releases.pop_back()
	var r: Dictionary = RhythmJudge.judge(io[0], releases, _tier1())
	assert_false(r.passed)
	assert_eq(r.reason, "unreleased")


func test_absolute_floor_for_short_beats() -> void:
	# 100 ms steps: interval target 200 ms; 20% of 200 ms = 40 ms, so the 100 ms floor applies.
	var fast := _rhythm([100.0, 100.0, 100.0] as Array[float], 100, 0.2)
	assert_true(_judge([50, 50], [300], fast).passed)
	assert_false(_judge([50, 50], [301], fast).passed)


func test_uniformly_slow_within_tolerance_passes() -> void:
	# Every interval and the hold 25% long: each check is fine on its own.
	assert_true(_judge([300, 750, 300], [750, 1125]).passed)


func test_half_steps_are_taps() -> void:
	# Syncopated: 1.5 steps is a hold, 0.5 steps a tap.
	var sync := _rhythm([150.0, 300.0, 450.0] as Array[float])
	assert_true(_judge([60, 450], [450], sync).passed, "0.5-step tap not timed")
	assert_false(_judge([60, 250], [450], sync).passed, "1.5-step hold is timed")


func test_allowance_and_max_total() -> void:
	assert_eq(RhythmJudge.allowance(100.0, 0.3, 100.0), 100.0)
	assert_almost_eq(RhythmJudge.allowance(600.0, 0.3, 100.0), 180.0, 0.001)
	# Intervals 600+180 and 900+270, then the last beat 300+100 (the floor).
	assert_almost_eq(RhythmJudge.max_total_ms(_tier1()), 2350.0, 0.001)
