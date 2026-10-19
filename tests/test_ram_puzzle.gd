extends "res://tests/hardwire_test.gd"
## RamPuzzle behaviour, driven by simulated frames.


func _enter(puzzle: PuzzleBase, cells: Array[int]) -> void:
	for i: int in cells:
		puzzle.toggle_cell(i)


func test_watch_shows_pattern_then_hides() -> void:
	var puzzle := make_puzzle(RamPuzzle, 5)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	puzzle._process(FRAME)
	assert_eq(puzzle.grid().on_cells(), puzzle.pattern())
	var t: float = 0.0
	while puzzle.phase == PuzzleBase.Phase.WATCH:
		puzzle._process(FRAME)
		t += FRAME
	assert_almost_eq(t, 2.1, 2 * FRAME, "tier 5 shows for 2100 ms")
	assert_eq(puzzle.grid().on_cells(), [] as Array[int], "all cells dark for input")


func test_toggle_on_and_off() -> void:
	var puzzle := make_puzzle(RamPuzzle, 1)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	puzzle.toggle_cell(4)
	assert_true(puzzle.grid().is_on(4))
	puzzle.toggle_cell(4)
	assert_false(puzzle.grid().is_on(4))


func test_toggle_ignored_outside_input() -> void:
	var puzzle := make_puzzle(RamPuzzle, 1)
	puzzle.toggle_cell(0)
	assert_false(puzzle.grid().is_on(0))


func test_commit_disabled_until_count_matches() -> void:
	var puzzle := make_puzzle(RamPuzzle, 1)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	var target: Array[int] = puzzle.expected()
	_enter(puzzle, target.slice(0, target.size() - 1))
	assert_false(puzzle.can_commit())
	puzzle.commit()
	assert_eq(puzzle.phase, PuzzleBase.Phase.INPUT, "commit ignored")
	puzzle.toggle_cell(target[-1])
	assert_true(puzzle.can_commit())


func test_correct_commit_solves() -> void:
	var puzzle := make_puzzle(RamPuzzle, 20)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	assert_eq(puzzle.grid().n, 6)
	_enter(puzzle, puzzle.expected())
	puzzle.commit()
	assert_signal_emitted(puzzle, "solved")
	assert_signal_not_emitted(puzzle, "failed")


func test_correction_then_commit_solves() -> void:
	var puzzle := make_puzzle(RamPuzzle, 1)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	var wrong: int = _not_in(puzzle.expected(), 9)
	puzzle.toggle_cell(wrong)
	puzzle.toggle_cell(wrong)
	_enter(puzzle, puzzle.expected())
	puzzle.commit()
	assert_signal_emitted(puzzle, "solved")


func test_wrong_commit_fails_and_flashes_answer() -> void:
	var puzzle := make_puzzle(RamPuzzle, 1)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	var target: Array[int] = puzzle.expected()
	var cells: Array[int] = target.slice(0, target.size() - 1)
	cells.append(_not_in(target, 9))
	_enter(puzzle, cells)
	puzzle.commit()
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)
	assert_eq(puzzle.grid().on_cells(), target, "correct pattern is shown")
	assert_signal_not_emitted(puzzle, "failed")
	run_until(puzzle, PuzzleBase.Phase.IDLE, 2.0)
	assert_signal_emitted(puzzle, "failed")


func test_timeout_fails_and_flashes_answer() -> void:
	var puzzle := make_puzzle(RamPuzzle, 1)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	puzzle.toggle_cell(_not_in(puzzle.expected(), 9))
	var t: float = 0.0
	while puzzle.phase == PuzzleBase.Phase.INPUT:
		puzzle._process(FRAME)
		t += FRAME
	assert_almost_eq(t, 6.4, 2 * FRAME, "4 s + 0.8 s x 3")
	assert_eq(puzzle.grid().on_cells(), puzzle.expected())
	run_until(puzzle, PuzzleBase.Phase.IDLE, 2.0)
	assert_signal_emitted(puzzle, "failed")


func test_inverted_solves_with_dark_cells() -> void:
	var puzzle := make_puzzle(RamPuzzle, 10, GridGen.MOD_INVERTED, 5)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	_enter(puzzle, puzzle.pattern())
	assert_false(puzzle.can_commit(), "the shown cells are not the answer")
	_enter(puzzle, puzzle.pattern())
	var dark: Array[int] = []
	for i: int in 25:
		if not puzzle.pattern().has(i):
			dark.append(i)
	_enter(puzzle, dark)
	puzzle.commit()
	assert_signal_emitted(puzzle, "solved")


func test_rotated_rejects_unrotated_and_accepts_rotated() -> void:
	var puzzle := make_puzzle(RamPuzzle, 5, GridGen.MOD_ROTATED, 2)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	assert_ne(
		puzzle.pattern(), puzzle.expected(), "seed gives a pattern that changes under rotation"
	)
	var rotated: Array[int] = []
	for i: int in puzzle.pattern():
		rotated.append(GridGen.rotate_cw(i, 4))
	_enter(puzzle, rotated)
	puzzle.commit()
	assert_signal_emitted(puzzle, "solved")

	var second := make_puzzle(RamPuzzle, 5, GridGen.MOD_ROTATED, 2)
	watch_signals(second)
	run_until(second, PuzzleBase.Phase.INPUT)
	_enter(second, second.pattern())
	second.commit()
	assert_eq(second.phase, PuzzleBase.Phase.RESULT)
	assert_signal_not_emitted(second, "solved")


func _not_in(cells: Array[int], count: int) -> int:
	for i: int in count:
		if not cells.has(i):
			return i
	return -1
