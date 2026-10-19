extends "res://tests/hardwire_test.gd"
## StoragePuzzle and PuzzleScreen behaviour, driven by simulated frames (no real time passes).

const StoragePuzzle := preload("res://scenes/puzzles/StoragePuzzle.gd")
const PuzzleScreen := preload("res://scenes/screens/PuzzleScreen.gd")


func _puzzle(tier: int, modifier: String = "", seed: int = 7) -> PuzzleBase:
	var puzzle: PuzzleBase = StoragePuzzle.new()
	puzzle.size = Vector2(1000, 1200)
	add_child_autofree(puzzle)
	puzzle.setup(SlotDef.create(tier, SlotDef.TYPE_STO, modifier), seed)
	puzzle.start()
	return puzzle


func _run_until(puzzle: PuzzleBase, phase: PuzzleBase.Phase, max_s: float = 30.0) -> void:
	var t: float = 0.0
	while puzzle.phase != phase and t < max_s:
		puzzle._process(FRAME)
		for pad: StoragePad in puzzle.pads():
			pad._process(FRAME)
		t += FRAME


func test_watch_then_input() -> void:
	var puzzle := _puzzle(1)
	assert_eq(puzzle.phase, PuzzleBase.Phase.COUNTDOWN)
	_run_until(puzzle, PuzzleBase.Phase.WATCH)
	assert_eq(puzzle.phase, PuzzleBase.Phase.WATCH)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	assert_eq(puzzle.phase, PuzzleBase.Phase.INPUT)
	assert_eq(puzzle.pads().size(), 4)


func test_watch_duration_matches_timings() -> void:
	var puzzle := _puzzle(1)
	_run_until(puzzle, PuzzleBase.Phase.WATCH)
	var t: float = 0.0
	while puzzle.phase == PuzzleBase.Phase.WATCH:
		puzzle._process(FRAME)
		t += FRAME
	# 3 items x (700 + 150) ms
	assert_almost_eq(t, 2.55, 2 * FRAME)


func test_watch_lights_each_item() -> void:
	var puzzle := _puzzle(5, "", 3)
	_run_until(puzzle, PuzzleBase.Phase.WATCH)
	var lit_order: Array[int] = []
	var was_lit: int = -1
	while puzzle.phase == PuzzleBase.Phase.WATCH:
		puzzle._process(FRAME)
		var lit: int = -1
		for pad: StoragePad in puzzle.pads():
			if pad.level() > 0.0:
				lit = pad.index
		if lit != was_lit and lit >= 0:
			lit_order.append(lit)
		was_lit = lit
	assert_eq(lit_order, puzzle.expected())


func test_correct_input_solves() -> void:
	var puzzle := _puzzle(20)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	assert_eq(puzzle.pads().size(), 8)
	for pad: int in puzzle.expected():
		puzzle.tap_pad(pad)
	assert_signal_emitted(puzzle, "solved")
	assert_signal_not_emitted(puzzle, "failed")
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)


func test_wrong_tap_fails_after_reveal() -> void:
	var puzzle := _puzzle(5)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	var first: int = puzzle.expected()[0]
	puzzle.tap_pad((first + 1) % puzzle.pads().size())
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)
	assert_eq(puzzle.pads()[first].level(), 1.0, "correct pad is revealed")
	assert_signal_not_emitted(puzzle, "failed", "failed waits for the reveal")
	_run_until(puzzle, PuzzleBase.Phase.IDLE, 2.0)
	assert_signal_emitted(puzzle, "failed")
	assert_signal_not_emitted(puzzle, "solved")


func test_timeout_fails() -> void:
	var puzzle := _puzzle(1)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	puzzle.tap_pad(puzzle.expected()[0])
	_run_until(puzzle, PuzzleBase.Phase.RESULT, 5.0)
	assert_eq(puzzle.time_left_s, 0.0)
	assert_eq(puzzle.pads()[puzzle.expected()[1]].level(), 1.0, "next expected pad is revealed")
	_run_until(puzzle, PuzzleBase.Phase.IDLE, 2.0)
	assert_signal_emitted(puzzle, "failed")


func test_input_ignored_outside_input_phase() -> void:
	var puzzle := _puzzle(1)
	puzzle.tap_pad(0)
	assert_eq(puzzle.progress(), 0)
	assert_eq(puzzle.phase, PuzzleBase.Phase.COUNTDOWN)


func test_reverse_accepts_back_to_front() -> void:
	var puzzle := _puzzle(8, SequenceGen.MOD_REVERSE, 11)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	var seq: Array[int] = SequenceGen.make(puzzle.slot, puzzle.attempt_seed).sequence
	for i: int in range(seq.size() - 1, -1, -1):
		puzzle.tap_pad(seq[i])
	assert_signal_emitted(puzzle, "solved")


func test_decoy_is_dim_and_not_expected() -> void:
	var puzzle := _puzzle(8, SequenceGen.MOD_DECOY, 5)
	watch_signals(puzzle)
	_run_until(puzzle, PuzzleBase.Phase.WATCH)
	var saw_dim: bool = false
	while puzzle.phase == PuzzleBase.Phase.WATCH:
		puzzle._process(FRAME)
		for pad: StoragePad in puzzle.pads():
			if pad.level() > 0.0 and pad.level() < 1.0:
				saw_dim = true
	assert_true(saw_dim, "decoy flashes dimly")
	for pad: int in puzzle.expected():
		puzzle.tap_pad(pad)
	assert_signal_emitted(puzzle, "solved")


func test_screen_restarts_with_new_sequence_after_failure() -> void:
	var screen: Control = PuzzleScreen.new()
	screen.setup(SlotDef.create(5, SlotDef.TYPE_STO))
	screen.size = Vector2(1080, 1920)
	add_child_autofree(screen)
	var puzzle: PuzzleBase = screen.puzzle
	_run_until(puzzle, PuzzleBase.Phase.INPUT)
	var first_seed: int = puzzle.attempt_seed
	var first: int = puzzle.expected()[0]
	puzzle.tap_pad((first + 1) % puzzle.pads().size())
	_run_until(puzzle, PuzzleBase.Phase.COUNTDOWN, 2.0)
	assert_eq(puzzle.phase, PuzzleBase.Phase.COUNTDOWN, "next attempt starts automatically")
	assert_ne(puzzle.attempt_seed, first_seed, "with a fresh seed")
	assert_eq(puzzle.slot.tier, 5, "at the same difficulty")
