# gdlint: disable=max-public-methods
extends "res://tests/hardwire_test.gd"
## StoragePuzzle and PuzzleScreen behaviour, driven by simulated frames (no real time passes,
## except in the hold tests: a pad's minimum light is a real-time tween).

## Longer than the theme's tap_flash_ms (180 ms), the shortest a pressed pad stays lit.
const PAST_MIN_FLASH_S := 0.3


func test_watch_then_input() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 1)
	assert_eq(puzzle.phase, PuzzleBase.Phase.COUNTDOWN)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	assert_eq(puzzle.phase, PuzzleBase.Phase.WATCH)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	assert_eq(puzzle.phase, PuzzleBase.Phase.INPUT)
	assert_eq(puzzle.pads().size(), 4)


func test_watch_duration_matches_timings() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 1)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	var t: float = 0.0
	while puzzle.phase == PuzzleBase.Phase.WATCH:
		puzzle._process(FRAME)
		t += FRAME
	# 3 items x (700 + 150) ms
	assert_almost_eq(t, 2.55, 2 * FRAME)


func test_watch_lights_each_item() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 5, "", 3)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
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


func test_touch_on_pad_taps_it() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 1, "", 7, true)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	await wait_process_frames(1)
	var viewport: Viewport = puzzle.get_viewport()
	tap_at(viewport, Vector2.ZERO)
	assert_eq(puzzle.progress(), 0, "a touch between pads is not a tap")
	for pad: int in puzzle.expected():
		tap_at(viewport, puzzle.pads()[pad].get_global_rect().get_center())
	assert_signal_emitted(puzzle, "solved")


func test_correct_input_solves() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 20)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	assert_eq(puzzle.pads().size(), 8)
	for pad: int in puzzle.expected():
		puzzle.tap_pad(pad)
	assert_signal_emitted(puzzle, "solved")
	assert_signal_not_emitted(puzzle, "failed")
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)


func test_wrong_tap_fails_after_reveal() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 5)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	var first: int = puzzle.expected()[0]
	puzzle.tap_pad((first + 1) % puzzle.pads().size())
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)
	assert_eq(puzzle.pads()[first].level(), 1.0, "correct pad is revealed")
	assert_signal_not_emitted(puzzle, "failed", "failed waits for the reveal")
	run_until(puzzle, PuzzleBase.Phase.IDLE, 2.0)
	assert_signal_emitted(puzzle, "failed")
	assert_signal_not_emitted(puzzle, "solved")


func test_timeout_fails() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 1)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	puzzle.tap_pad(puzzle.expected()[0])
	run_until(puzzle, PuzzleBase.Phase.RESULT, 5.0)
	assert_eq(puzzle.time_left_s, 0.0)
	assert_eq(puzzle.pads()[puzzle.expected()[1]].level(), 1.0, "next expected pad is revealed")
	run_until(puzzle, PuzzleBase.Phase.IDLE, 2.0)
	assert_signal_emitted(puzzle, "failed")


func test_input_ignored_outside_input_phase() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 1)
	puzzle.tap_pad(0)
	assert_eq(puzzle.progress(), 0)
	assert_eq(puzzle.phase, PuzzleBase.Phase.COUNTDOWN)


func test_reverse_accepts_back_to_front() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 8, SequenceGen.MOD_REVERSE, 11)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	var seq: Array[int] = SequenceGen.make(puzzle.slot, puzzle.attempt_seed).sequence
	for i: int in range(seq.size() - 1, -1, -1):
		puzzle.tap_pad(seq[i])
	assert_signal_emitted(puzzle, "solved")


func test_decoy_is_dim_and_not_expected() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 8, SequenceGen.MOD_DECOY, 5)
	watch_signals(puzzle)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
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
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	var first_seed: int = puzzle.attempt_seed
	var first: int = puzzle.expected()[0]
	puzzle.tap_pad((first + 1) % puzzle.pads().size())
	run_until(puzzle, PuzzleBase.Phase.COUNTDOWN, 2.0)
	assert_eq(puzzle.phase, PuzzleBase.Phase.COUNTDOWN, "next attempt starts automatically")
	assert_ne(puzzle.attempt_seed, first_seed, "with a fresh seed")
	assert_eq(puzzle.slot.tier, 5, "at the same difficulty")


func test_pad_stays_lit_while_accept_is_held() -> void:
	var puzzle := await _input_ready()
	var pad: StoragePad = puzzle.pads()[puzzle.expected()[0]]
	pad.grab_focus()
	press_action(puzzle.get_viewport(), "ui_accept", true)
	await wait_seconds(PAST_MIN_FLASH_S)
	assert_eq(pad.level(), 1.0, "lit while held")
	press_action(puzzle.get_viewport(), "ui_accept", false)
	assert_eq(pad.level(), 0.0, "dark on release")
	assert_eq(puzzle.progress(), 1, "the press counted")


func test_pad_stays_lit_while_touched() -> void:
	var puzzle := await _input_ready()
	var pad: StoragePad = puzzle.pads()[puzzle.expected()[0]]
	var center: Vector2 = pad.get_global_rect().get_center()
	tap_at(puzzle.get_viewport(), center, [true])
	await wait_seconds(PAST_MIN_FLASH_S)
	assert_eq(pad.level(), 1.0, "lit while touched")
	tap_at(puzzle.get_viewport(), center, [false])
	assert_eq(pad.level(), 0.0, "dark on release")


func test_quick_tap_still_flashes_for_the_minimum() -> void:
	var puzzle := await _input_ready()
	var pad: StoragePad = puzzle.pads()[puzzle.expected()[0]]
	tap_at(puzzle.get_viewport(), pad.get_global_rect().get_center())
	assert_eq(pad.level(), 1.0, "lit right after a quick tap")
	await wait_seconds(PAST_MIN_FLASH_S)
	assert_eq(pad.level(), 0.0, "dark after the minimum")


func test_release_ends_the_hold_even_after_focus_moved() -> void:
	var puzzle := await _input_ready()
	var first: int = puzzle.expected()[0]
	var pad: StoragePad = puzzle.pads()[first]
	pad.grab_focus()
	press_action(puzzle.get_viewport(), "ui_accept", true)
	await wait_seconds(PAST_MIN_FLASH_S)
	puzzle.pads()[(first + 1) % puzzle.pads().size()].grab_focus()
	press_action(puzzle.get_viewport(), "ui_accept", false)
	assert_eq(pad.level(), 0.0, "the held pad goes dark")


func test_wrong_press_fails_without_lighting_or_holding() -> void:
	GameState.settings.haptics = true
	var puzzle := await _input_ready()
	var first: int = puzzle.expected()[0]
	var wrong: StoragePad = puzzle.pads()[(first + 1) % puzzle.pads().size()]
	wrong.grab_focus()
	press_action(puzzle.get_viewport(), "ui_accept", true)
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)
	assert_eq(wrong.level(), 0.0, "the wrong pad does not light")
	assert_false(Haptics.active, "no hold rumble")
	assert_eq(puzzle.pads()[first].level(), 1.0, "the correct pad is revealed")
	press_action(puzzle.get_viewport(), "ui_accept", false)


func test_winning_press_still_flashes() -> void:
	var puzzle := await _input_ready()
	var seq: Array[int] = puzzle.expected()
	for i: int in seq.size() - 1:
		puzzle.tap_pad(seq[i])
		puzzle.release_pad()
	var last: StoragePad = puzzle.pads()[seq[-1]]
	tap_at(puzzle.get_viewport(), last.get_global_rect().get_center())
	assert_eq(puzzle.phase, PuzzleBase.Phase.RESULT)
	assert_eq(last.level(), 1.0, "the solving press shows")


func test_hold_rumbles_until_release() -> void:
	GameState.settings.haptics = true
	var puzzle := await _input_ready()
	puzzle.pads()[puzzle.expected()[0]].grab_focus()
	press_action(puzzle.get_viewport(), "ui_accept", true)
	assert_true(Haptics.active, "rumbles while held")
	press_action(puzzle.get_viewport(), "ui_accept", false)
	assert_false(Haptics.active, "stops on release")


func test_a_second_press_moves_the_hold() -> void:
	var puzzle := await _input_ready()
	var seq: Array[int] = puzzle.expected()
	var first: StoragePad = puzzle.pads()[seq[0]]
	var second: StoragePad = puzzle.pads()[seq[1]]
	first.grab_focus()
	press_action(puzzle.get_viewport(), "ui_accept", true)
	tap_at(puzzle.get_viewport(), second.get_global_rect().get_center(), [true])
	await wait_seconds(PAST_MIN_FLASH_S)
	assert_eq(first.level(), 0.0, "the first pad lets go")
	assert_eq(second.level(), 1.0, "the second pad holds")
	tap_at(puzzle.get_viewport(), second.get_global_rect().get_center(), [false])
	assert_eq(second.level(), 0.0)
	press_action(puzzle.get_viewport(), "ui_accept", false)


func test_freeing_the_puzzle_mid_hold_stops_the_rumble() -> void:
	GameState.settings.haptics = true
	var puzzle := await _input_ready()
	puzzle.pads()[puzzle.expected()[0]].grab_focus()
	press_action(puzzle.get_viewport(), "ui_accept", true)
	assert_true(Haptics.active)
	puzzle.free()
	assert_false(Haptics.active, "a screen rebuilt mid-hold leaves nothing running")


## A touchable tier 1 puzzle in its input phase, ready for pushed input.
func _input_ready() -> StoragePuzzle:
	var puzzle := make_puzzle(StoragePuzzle, 1, "", 7, true) as StoragePuzzle
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	await wait_process_frames(2)
	return puzzle
