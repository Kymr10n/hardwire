# gdlint: disable=max-public-methods
extends "res://tests/hardwire_test.gd"
## CpuPuzzle behaviour with synthetic timestamps and simulated frames.

const CpuPuzzle := preload("res://scenes/puzzles/CpuPuzzle.gd")


func _puzzle(tier: int, modifier: String = "", seed: int = 7) -> PuzzleBase:
	var puzzle: PuzzleBase = CpuPuzzle.new()
	puzzle.size = Vector2(1000, 1400)
	add_child_autofree(puzzle)
	puzzle.setup(SlotDef.create(tier, SlotDef.TYPE_CPU, modifier), seed)
	puzzle.start()
	return puzzle


func _run(puzzle: PuzzleBase, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		puzzle._process(FRAME)
		t += FRAME


func _run_until(puzzle: PuzzleBase, phase: PuzzleBase.Phase, max_s: float = 30.0) -> void:
	var t: float = 0.0
	while puzzle.phase != phase and t < max_s:
		puzzle._process(FRAME)
		t += FRAME


## Plays the target with each segment scaled by `factor` (and segment `bad` scaled by `bad_factor`).
func _play(puzzle: PuzzleBase, factor: float = 1.0, bad: int = -1, bad_factor: float = 1.0) -> void:
	var target: Array[float] = puzzle.attempt().target_ms
	var t: float = 1_000_000.0
	for i: int in target.size():
		if i % 2 == 0:
			puzzle.press_at(int(t))
		var f: float = bad_factor if i == bad else factor
		t += target[i] * f * 1000.0
		if i % 2 == 0:
			puzzle.release_at(int(t))


func test_watch_plays_rhythm_on_tile() -> void:
	var puzzle := _puzzle(1)
	_run_until(puzzle, PuzzleBase.Phase.WATCH)
	var target: Array[float] = puzzle.attempt().target_ms
	var lit_ms: float = 0.0
	var watch_ms: float = 0.0
	while puzzle.phase == PuzzleBase.Phase.WATCH:
		puzzle._process(FRAME)
		watch_ms += FRAME * 1000.0
		if puzzle.tile().lit:
			lit_ms += FRAME * 1000.0
	var on_ms: float = 0.0
	for i: int in range(0, target.size(), 2):
		on_ms += target[i]
	assert_almost_eq(watch_ms, puzzle.attempt().total_ms, 2 * FRAME * 1000.0)
	assert_almost_eq(lit_ms, on_ms, target.size() * FRAME * 1000.0)


func test_audio_only_tile_stays_dark() -> void:
	var puzzle := _puzzle(8, RhythmGen.MOD_AUDIO_ONLY)
	_run_until(puzzle, PuzzleBase.Phase.WATCH)
	var any_lit: bool = false
	while puzzle.phase == PuzzleBase.Phase.WATCH:
		puzzle._process(FRAME)
		any_lit = any_lit or puzzle.tile().lit
	assert_false(any_lit)


func test_exact_rhythm_solves_after_grace() -> void:
	var puzzle := _puzzle(1)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	_play(puzzle)
	assert_eq(puzzle.phase, PuzzleBase.Phase.INPUT, "waits for extra presses")
	_run(puzzle, 0.55)
	assert_signal_not_emitted(puzzle, "solved")
	_run(puzzle, 0.1)
	assert_signal_emitted(puzzle, "solved")


func test_one_segment_off_fails() -> void:
	var puzzle := _puzzle(1)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	_play(puzzle, 1.0, 2, 1.6)
	_run(puzzle, 0.7)
	assert_eq(puzzle.last_result().reason, "timing")
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)
	_run_until(puzzle, PuzzleBase.Phase.IDLE, 2.0)
	assert_signal_emitted(puzzle, "failed")


func test_extra_press_fails_at_once() -> void:
	var puzzle := _puzzle(1)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	_play(puzzle)
	puzzle.press_at(9_000_000)
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)
	assert_false(puzzle.tile().lit or puzzle.phase == PuzzleBase.Phase.INPUT)


func test_no_first_press_times_out_after_5_s() -> void:
	var puzzle := _puzzle(1)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	_run(puzzle, 4.9)
	assert_eq(puzzle.phase, PuzzleBase.Phase.INPUT)
	_run(puzzle, 0.2)
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)
	_run_until(puzzle, PuzzleBase.Phase.IDLE, 2.0)
	assert_signal_emitted(puzzle, "failed")


func test_slow_player_not_cut_off() -> void:
	# All segments 25% long (within 30%): input must stay open past the target length + 600 ms.
	var puzzle := _puzzle(1)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	var target: Array[float] = puzzle.attempt().target_ms
	var t: float = 0.0
	var usec: float = 1_000_000.0
	for i: int in target.size():
		if i % 2 == 0:
			puzzle.press_at(int(usec))
		_run(puzzle, target[i] * 1.25 / 1000.0)
		usec += target[i] * 1.25 * 1000.0
		if i % 2 == 0:
			puzzle.release_at(int(usec))
	assert_eq(puzzle.phase, PuzzleBase.Phase.INPUT)
	_run(puzzle, 0.7)
	assert_signal_emitted(puzzle, "solved")


func test_holding_too_long_ends_input() -> void:
	var puzzle := _puzzle(1)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	puzzle.press_at(1_000_000)
	_run(puzzle, (puzzle.attempt().max_total_ms + 600.0) / 1000.0 + 0.1)
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)
	assert_false(puzzle.last_result().passed)
	assert_eq(puzzle.last_result().reason, "count")


func test_fail_reveal_replays_rhythm() -> void:
	var puzzle := _puzzle(1)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	_run(puzzle, 5.1)
	var lit_frames: int = 0
	var dark_frames: int = 0
	while puzzle.phase == PuzzleBase.Phase.RESULT:
		puzzle._process(FRAME)
		if puzzle.tile().lit:
			lit_frames += 1
		else:
			dark_frames += 1
	assert_gt(lit_frames, 0)
	assert_gt(dark_frames, 0)


## First seed whose tier-1 rhythm has a tap before the last beat (where the D-022 bug showed).
func _seed_with_interior_tap() -> int:
	for seed: int in 100:
		var steps: Array[float] = RhythmGen.make(SlotDef.create(1, SlotDef.TYPE_CPU), seed).steps
		for i: int in range(0, steps.size() - 1, 2):
			if steps[i] <= 1.0:
				return seed
	return -1


func test_quick_clicks_on_taps_solve() -> void:
	# Play-test (D-022): mouse clicks last about 100 ms; taps (1 step) must still count.
	var seed: int = _seed_with_interior_tap()
	assert_gte(seed, 0, "found a rhythm with a tap in the middle")
	var puzzle := _puzzle(1, "", seed)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	var a: Dictionary = puzzle.attempt()
	var steps: Array[float] = a.steps
	var t: float = 1_000_000.0
	for i: int in range(0, steps.size(), 2):
		var is_hold: bool = steps[i] > 1.0
		puzzle.press_at(int(t))
		puzzle.release_at(int(t + (steps[i] * a.step_ms if is_hold else 100.0) * 1000.0))
		if i + 1 < steps.size():
			t += (steps[i] + steps[i + 1]) * a.step_ms * 1000.0
	_run(puzzle, 0.7)
	assert_signal_emitted(puzzle, "solved", "judge: %s" % puzzle.last_result())


func _widths(puzzle: PuzzleBase) -> Array[float]:
	var out: Array[float] = []
	for rect: Rect2 in puzzle.marker_rects():
		out.append(snappedf(rect.size.x / (rect.size.y / 2.0), 0.001))
	return out


func test_markers_show_tap_and_hold_lengths() -> void:
	# Tier 1, seed 7: on-steps 3, 2, 1. Widths in radii: 2 per step for holds, 2 for a tap.
	var puzzle := _puzzle(1)
	var steps: Array[float] = puzzle.attempt().steps
	assert_eq(steps, [3.0, 2.0, 2.0, 2.0, 1.0] as Array[float], "fixture")
	assert_eq(_widths(puzzle), [6.0, 4.0, 2.0] as Array[float])


func test_markers_under_audio_only_are_plain_dots() -> void:
	var puzzle := _puzzle(1, RhythmGen.MOD_AUDIO_ONLY)
	assert_eq(_widths(puzzle), [2.0, 2.0, 2.0] as Array[float])
	_run_until(puzzle, PuzzleBase.Phase.WATCH)
	_run(puzzle, 1.0)
	assert_eq(puzzle.filled_markers(), 0, "no fill during playback")


func test_markers_fill_with_playback_and_presses() -> void:
	var puzzle := _puzzle(1)
	_run_until(puzzle, PuzzleBase.Phase.WATCH)
	_run(puzzle, 1.0)
	assert_eq(puzzle.filled_markers(), 1, "beat 0 (900 ms on, 600 ms off) is playing")
	_run(puzzle, 0.6)
	assert_eq(puzzle.filled_markers(), 2, "beat 1 starts at 1.5 s")
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	assert_eq(puzzle.filled_markers(), 0)
	puzzle.press_at(1_000_000)
	assert_eq(puzzle.filled_markers(), 1)


func test_markers_fit_long_rhythms() -> void:
	# Tier 40: 10 beats; on a narrow area the row stays inside the margins.
	var puzzle := _puzzle(40)
	puzzle.size = Vector2(600, 1200)
	var margin: float = puzzle.get_theme_constant("margin", "Hardwire")
	var rects: Array[Rect2] = puzzle.marker_rects()
	assert_eq(rects.size(), 10)
	assert_gte(rects[0].position.x, margin - 0.001)
	assert_lte(rects[-1].end.x, puzzle.size.x - margin + 0.001)
	puzzle.size = Vector2(3000, 1200)
	var tap: float = puzzle.get_theme_constant("tap_min", "Hardwire")
	var radius: float = puzzle.marker_rects()[0].size.y / 2.0
	assert_almost_eq(radius, tap * CpuPuzzle.MARKER_RADIUS, 0.001, "full size when it fits")


func test_fail_reveal_lasts_the_reveal_time() -> void:
	var puzzle := _puzzle(1)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	_run_until(puzzle, PuzzleBase.Phase.RESULT, 6.0)
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT, "first-press timeout")
	var t: float = 0.0
	while puzzle.phase == PuzzleBase.Phase.RESULT:
		puzzle._process(FRAME)
		t += FRAME
	assert_almost_eq(t, Balance.get_num("flow", "fail_reveal_s"), 2 * FRAME)


func test_input_window_ignores_debug_time_scale() -> void:
	# SPEC: judging and the input window use real time at every time scale (D-023).
	var puzzle := _puzzle(1)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	puzzle.press_at(1_000_000)
	var before: float = puzzle.time_left_s
	Engine.time_scale = 4.0
	puzzle._process(0.4)  # 0.4 s of scaled time = 0.1 s real
	assert_almost_eq(before - puzzle.time_left_s, 0.1, 0.0001)
