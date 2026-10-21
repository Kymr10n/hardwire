# gdlint: disable=max-public-methods
extends "res://tests/hardwire_test.gd"
## M12 (D-041): the glass overlay and its setting, the segmented timer, the puzzle bezel, the
## key and relay clicks, the dialog title strips.


## D-041: the glass overlay draws on every screen; the CRT setting turns it off but keeps the
## vignette (the shader's `glass` uniform).
func test_glass_overlay_follows_the_crt_setting() -> void:
	var main := make_main()
	main.show_overview()
	assert_eq(main.glass_level(), 1.0)
	GameState.set_setting("crt", false)
	assert_eq(main.glass_level(), 0.0)
	GameState.set_setting("crt", true)
	assert_eq(main.glass_level(), 1.0)
	var layers: Array[Node] = main.find_children("*", "CanvasLayer", false, false)
	assert_eq(layers.size(), 1, "one overlay layer above the screens")


## D-041: the timer is a segmented bar; the last block stays until time is up.
func test_timer_bar_segments() -> void:
	var bar := TimerBar.new()
	add_child_autofree(bar)
	var n: int = bar.get_theme_constant("timer_segments", "Hardwire")
	bar.value = 1.0
	assert_eq(bar.lit_segments(), n)
	bar.value = 0.5
	assert_eq(bar.lit_segments(), n / 2)
	bar.value = 0.01
	assert_eq(bar.lit_segments(), 1)
	bar.value = 0.0
	assert_eq(bar.lit_segments(), 0)


## D-041: the puzzle sits in a bezel that pulses on success.
func test_puzzle_bezel_pulses_on_solve() -> void:
	var screen: Control = PuzzleScreen.new()
	screen.setup(SlotGenerator.make(1, SlotDef.TYPE_STO))
	add_child_autofree(screen)
	await wait_process_frames(1)
	assert_true(screen.puzzle.get_parent() is Bezel)
	run_until(screen.puzzle, PuzzleBase.Phase.INPUT)
	for pad: int in screen.puzzle.expected():
		screen.puzzle.tap_pad(pad)
	assert_eq(screen.bezel.color, screen.get_theme_color("accent", "Hardwire"))


## D-041: the bezel pulses red when an attempt fails.
func test_puzzle_bezel_pulses_red_on_failure() -> void:
	var screen: Control = PuzzleScreen.new()
	screen.setup(SlotGenerator.make(1, SlotDef.TYPE_STO))
	add_child_autofree(screen)
	await wait_process_frames(1)
	run_until(screen.puzzle, PuzzleBase.Phase.INPUT)
	var pads: int = screen.puzzle.pads().size()
	screen.puzzle.tap_pad((screen.puzzle.expected()[0] + 1) % pads)
	assert_eq(screen.bezel.color, screen.get_theme_color("fail", "Hardwire"))


## D-041: every button clicks (like every button pulses, D-034) and every phase change relays.
func test_every_button_clicks_and_phases_relay() -> void:
	GameState.settings.sound = true
	var before: int = Synth.fx_played
	var button: Button = Ui.button("x", func() -> void: pass)
	add_child_autofree(button)
	button.pressed.emit()
	assert_eq(Synth.fx_played, before + 1, "a button click")
	var puzzle := make_puzzle(StoragePuzzle, 1)
	assert_eq(Synth.fx_played, before + 2, "relay on COUNTDOWN")
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	assert_eq(Synth.fx_played, before + 3, "relay on WATCH")
	Synth.stop_all()


## D-041: dialog titles are inverted strips: accent, red for Erase.
func test_dialog_title_strips() -> void:
	var settings := SettingsScreen.new()
	add_child_autofree(settings)
	var dialog := ConfirmDialog.open(settings, "Rebuild?", "m", "Rebuild")
	var strip := dialog.title_label.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(strip.bg_color, dialog.get_theme_color("accent", "Hardwire"))
	# Let the dialog's deferred focus grab run before it is freed with the screen.
	await wait_process_frames(1)
	dialog.cancel()
	await wait_process_frames(1)  # the cancelled dialog leaves the tree before the next opens
	settings._on_reset()
	var erase: ConfirmDialog = settings.find_children("*", "ConfirmDialog", true, false)[0]
	var red := erase.title_label.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(red.bg_color, settings.get_theme_color("fail", "Hardwire"))
	await wait_process_frames(1)
