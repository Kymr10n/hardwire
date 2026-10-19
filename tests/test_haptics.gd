extends "res://tests/hardwire_test.gd"
## Haptics (SPEC: Platforms and input > Haptics, Minigame: CPU > Haptics, Result overlay, D-024):
## what the hardware would be asked to do, observed through `active` and `last_pulse_ms`.


func test_everything_is_silent_when_haptics_are_off() -> void:
	GameState.settings.haptics = false
	Haptics.last_pulse_ms = 0
	Haptics.pulse()
	Haptics.start_hold()
	Haptics.success()
	Haptics.fail()
	assert_eq(Haptics.last_pulse_ms, 0)
	assert_false(Haptics.active)


func test_pulse_lengths_from_the_spec() -> void:
	GameState.settings.haptics = true
	Haptics.pulse()
	assert_eq(Haptics.last_pulse_ms, 20)
	Haptics.fail()
	assert_eq(Haptics.last_pulse_ms, 250, "one long pulse")
	Haptics.success()
	assert_eq(Haptics.last_pulse_ms, 60, "short pulse (twice)")


func test_hold_rumble_starts_and_stops() -> void:
	GameState.settings.haptics = true
	Haptics.start_hold()
	assert_true(Haptics.active)
	Haptics.stop_hold()
	assert_false(Haptics.active)


func test_cpu_playback_rumbles_with_the_tile() -> void:
	GameState.settings.haptics = true
	var puzzle := make_puzzle(CpuPuzzle, 1)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	run_for(puzzle, 0.1)
	assert_true(puzzle.tile().lit)
	assert_true(Haptics.active, "rumbles while the tile is lit")
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	assert_false(Haptics.active, "stops with playback")


func test_audio_only_playback_does_not_rumble() -> void:
	GameState.settings.haptics = true
	var puzzle := make_puzzle(CpuPuzzle, 8, RhythmGen.MOD_AUDIO_ONLY)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	run_for(puzzle, 0.1)
	assert_false(Haptics.active)


func test_cpu_hold_rumbles_while_pressed() -> void:
	GameState.settings.haptics = true
	var puzzle := make_puzzle(CpuPuzzle, 1)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	puzzle.press_at(1_000_000)
	assert_true(Haptics.active)
	puzzle.release_at(1_100_000)
	assert_false(Haptics.active)
	puzzle.press_at(2_000_000)
	puzzle.abort()
	assert_false(Haptics.active, "an aborted attempt stops the rumble")


func test_results_pulse() -> void:
	GameState.settings.haptics = true
	var puzzle := make_puzzle(StoragePuzzle, 1)
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	puzzle.tap_pad((puzzle.expected()[0] + 1) % puzzle.pads().size())
	assert_eq(Haptics.last_pulse_ms, 250, "failure: one long pulse")
	var win := make_puzzle(StoragePuzzle, 1)
	run_until(win, PuzzleBase.Phase.INPUT)
	for pad: int in win.expected():
		win.tap_pad(pad)
	assert_eq(Haptics.last_pulse_ms, 60, "success: short double pulse")
