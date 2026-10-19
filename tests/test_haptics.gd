# gdlint: disable=max-public-methods
extends "res://tests/hardwire_test.gd"
## Haptics (SPEC: Platforms and input > Haptics, Minigame: CPU > Haptics, Result overlay, D-024,
## D-034): what the hardware would be asked to do, observed through `active`, `last_pulse_ms`,
## `last_strength` and `pulses`.


func before_each() -> void:
	super.before_each()
	Haptics.pulses = 0
	Haptics.last_pulse_ms = 0


func _touch(pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.pressed = pressed
	return touch


func test_everything_is_silent_when_haptics_are_off() -> void:
	GameState.settings.haptics = false
	Haptics.pulse()
	Haptics.start_hold()
	Haptics.success()
	Haptics.fail()
	var button: Button = Ui.button("x", func() -> void: pass)
	add_child_autofree(button)
	button.pressed.emit()
	assert_eq(Haptics.last_pulse_ms, 0)
	assert_eq(Haptics.pulses, 0)
	assert_false(Haptics.active)


## D-034: the Haptics autoload hooks every button; screens never ask for the pulse themselves.
func test_every_button_pulses() -> void:
	GameState.settings.haptics = true
	var button: Button = Ui.button("x", func() -> void: pass)
	add_child_autofree(button)
	button.pressed.emit()
	assert_eq(Haptics.pulses, 1, "a Ui.button")
	assert_eq(Haptics.last_pulse_ms, 20)
	var card := SlotCard.new()
	card.setup(SlotGenerator.make(1, SlotDef.TYPE_RAM))
	add_child_autofree(card)
	card.pressed.emit()
	assert_eq(Haptics.pulses, 2, "a slot card")
	var host := Control.new()
	add_child_autofree(host)
	var dialog := ConfirmDialog.open(host, "t", "m", "OK")
	(dialog.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	assert_eq(Haptics.pulses, 3, "a dialog button")


func test_buying_pulses_once() -> void:
	GameState.settings.haptics = true
	GameState.add_cycles(1000)
	var shop := ShopScreen.new()
	add_child_autofree(shop)
	shop.cards[0].buy_button.pressed.emit()
	assert_eq(GameState.upgrade_level(shop.cards[0].id), 1, "bought")
	assert_eq(Haptics.pulses, 1, "the button's pulse, not a second one from the purchase")


func test_boot_and_hint_taps_pulse() -> void:
	GameState.settings.haptics = true
	var boot := BootScreen.new()
	add_child_autofree(boot)
	boot._input(_touch(false))  # a tap counts on release
	assert_eq(Haptics.pulses, 1, "tap to start")
	var hint := HintOverlay.new()
	add_child_autofree(hint)
	hint._gui_input(_touch(false))
	assert_eq(Haptics.pulses, 2, "hint dismissed")


func test_storage_playback_rumbles_with_the_pads() -> void:
	GameState.settings.haptics = true
	var puzzle := make_puzzle(StoragePuzzle, 1)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	var frames_lit: int = 0
	var frames_dark: int = 0
	var mismatches: int = 0
	while puzzle.phase == PuzzleBase.Phase.WATCH:
		puzzle._process(FRAME)
		var lit: bool = false
		for pad: StoragePad in puzzle.pads():
			lit = lit or pad.level() > 0.0
		if lit:
			frames_lit += 1
		else:
			frames_dark += 1
		if lit != Haptics.active:
			mismatches += 1
	assert_gt(frames_lit, 0)
	assert_gt(frames_dark, 0, "gaps between pads")
	assert_eq(mismatches, 0, "rumbles exactly while a pad is lit")
	assert_false(Haptics.active, "silent for input")


func test_decoy_pads_rumble_weaker() -> void:
	GameState.settings.haptics = true
	var puzzle := make_puzzle(StoragePuzzle, 8, SequenceGen.MOD_DECOY, 5)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	var decoy: float = Balance.get_num("haptics", "decoy_strength")
	var full: float = Balance.get_num("haptics", "hold_strength")
	assert_lt(decoy, full, "decoys rumble weaker")
	var saw_decoy: bool = false
	var saw_full: bool = false
	while puzzle.phase == PuzzleBase.Phase.WATCH:
		puzzle._process(FRAME)
		for pad: StoragePad in puzzle.pads():
			if pad.level() > 0.0 and pad.level() < 1.0:
				saw_decoy = true
				assert_almost_eq(Haptics.last_strength, decoy, 0.0001, "decoy strength")
			elif pad.level() >= 1.0:
				saw_full = true
				assert_almost_eq(Haptics.last_strength, full, 0.0001, "hold strength")
	assert_true(saw_decoy and saw_full)


func test_ram_playback_rumbles_while_pattern_shows() -> void:
	GameState.settings.haptics = true
	var puzzle := make_puzzle(RamPuzzle, 1)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	puzzle._process(FRAME)
	assert_eq(puzzle.grid().on_cells(), puzzle.pattern(), "pattern shown")
	assert_true(Haptics.active, "rumbles while the pattern shows")
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	assert_false(Haptics.active, "silent once the grid is dark")
	puzzle.abort()
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
