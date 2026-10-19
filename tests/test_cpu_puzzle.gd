extends GutTest
## CpuPuzzle behaviour with synthetic timestamps and simulated frames.

const CpuPuzzle := preload("res://scenes/puzzles/CpuPuzzle.gd")
const FRAME := 1.0 / 60.0

var _orig_sound: bool


func before_each() -> void:
	_orig_sound = GameState.settings.sound
	GameState.settings.sound = false


func after_each() -> void:
	GameState.settings.sound = _orig_sound


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
