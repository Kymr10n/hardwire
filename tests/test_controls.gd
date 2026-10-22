extends "res://tests/hardwire_test.gd"
## Gamepad / keyboard controls (SPEC: Controls): every minigame and the menus work without touch.

const LANDSCAPE := Vector2i(1920, 1080)


func _puzzle_screen(tier: int, type: String, modifier: String = "") -> Control:
	var screen := PuzzleScreen.new()
	screen.setup(SlotDef.create(tier, type, modifier))
	in_viewport(screen, LANDSCAPE)
	Ui.focus_first(screen)  # as Main._show does
	await wait_process_frames(2)
	for i: int in 3000:
		if screen.puzzle.phase == PuzzleBase.Phase.INPUT:
			break
		screen.puzzle._process(FRAME)
	return screen


func _focus_owner(node: Node) -> Control:
	return node.get_viewport().gui_get_focus_owner()


func test_storage_with_controller() -> void:
	var screen: Control = await _puzzle_screen(20, SlotDef.TYPE_STO)
	var viewport: Viewport = screen.get_viewport()
	var puzzle: PuzzleBase = screen.puzzle
	assert_eq(_focus_owner(screen), puzzle.pads()[0], "first pad has focus")
	tap_action(viewport, "ui_right")
	var moved := _focus_owner(screen) as StoragePad
	assert_not_null(moved, "focus moves around the ring")
	assert_ne(moved, puzzle.pads()[0])
	watch_signals(puzzle)
	for pad: int in puzzle.expected():
		puzzle.pads()[pad].grab_focus()
		tap_action(viewport, "ui_accept")
	assert_signal_emitted(puzzle, "solved")


func test_ram_with_controller() -> void:
	var screen: Control = await _puzzle_screen(5, SlotDef.TYPE_RAM)
	var viewport: Viewport = screen.get_viewport()
	var puzzle: PuzzleBase = screen.puzzle
	var grid: RamGrid = puzzle.grid()
	assert_eq(_focus_owner(screen), grid, "grid has focus")
	watch_signals(puzzle)
	for cell: int in puzzle.expected():
		# Walk the cursor to the cell with directions (bounded, so a broken input path fails
		# instead of hanging), then toggle it.
		for step: int in 2 * grid.n:
			var dx: int = cell % grid.n - grid.cursor % grid.n
			var dy: int = floori(cell / float(grid.n)) - floori(grid.cursor / float(grid.n))
			if dx != 0:
				tap_action(viewport, "ui_right" if dx > 0 else "ui_left")
			elif dy != 0:
				tap_action(viewport, "ui_down" if dy > 0 else "ui_up")
		assert_eq(grid.cursor, cell, "cursor reached cell %d" % cell)
		tap_action(viewport, "ui_accept")
	assert_eq(grid.on_cells(), puzzle.expected())
	tap_action(viewport, "commit")
	assert_signal_emitted(puzzle, "solved")


func test_ram_cursor_edge_releases_focus() -> void:
	var screen: Control = await _puzzle_screen(1, SlotDef.TYPE_RAM)
	var viewport: Viewport = screen.get_viewport()
	var grid: RamGrid = screen.puzzle.grid()
	tap_action(viewport, "ui_left")
	assert_eq(grid.cursor, 0, "cursor stays at the edge")
	assert_ne(_focus_owner(screen), grid, "focus moves on past the edge")


func test_cpu_hold_with_controller() -> void:
	var screen: Control = await _puzzle_screen(1, SlotDef.TYPE_CPU)
	var viewport: Viewport = screen.get_viewport()
	var puzzle: PuzzleBase = screen.puzzle
	assert_eq(_focus_owner(screen), puzzle.tile())
	# A press and release through the action are recorded like touch; timing itself is covered
	# deterministically in test_cpu_puzzle.
	press_action(viewport, "ui_accept", true)
	assert_true(puzzle.tile().lit, "holding")
	press_action(viewport, "ui_accept", false)
	assert_false(puzzle.tile().lit, "released")
	assert_eq(puzzle.markers.filled, 1, "one beat recorded")


func test_menus_have_focus_and_b_goes_back() -> void:
	var main := make_main()
	main.show_overview()
	await wait_process_frames(2)
	assert_true(_focus_owner(main) is SlotCard, "overview focuses a slot card")
	main.show_shop()
	await wait_process_frames(2)
	assert_true(_focus_owner(main) is Button, "shop focuses a button")
	tap_action(main.get_viewport(), "ui_cancel")
	assert_true(main.screen is OverviewScreen, "B goes back")


func test_dialog_focus_and_cancel() -> void:
	var main := make_main()
	main.show_settings()
	var dialog := ConfirmDialog.open(main.screen, "t", "m", "OK")
	await wait_process_frames(2)
	assert_eq((_focus_owner(main) as Button).text, "OK", "confirm button has focus")
	watch_signals(dialog)
	tap_action(main.get_viewport(), "ui_cancel")
	assert_signal_emitted(dialog, "cancelled")
	assert_false(main.screen is OverviewScreen, "B closed the dialog, not the screen")
	await wait_process_frames(2)
	var owner: Control = _focus_owner(main)
	assert_true(
		owner != null and main.screen.is_ancestor_of(owner), "the screen under it has focus again"
	)


## The "While you were away" dialog on start: A collects, then the overview must answer the
## gamepad again (a freed button leaves nothing focused unless the dialog hands focus back).
func test_collect_dialog_returns_focus_to_the_overview() -> void:
	GameState.apply_solve(SlotGenerator.make(5, SlotDef.TYPE_RAM))
	GameState.last_seen = int(Time.get_unix_time_from_system()) - 2 * 3600
	var main := make_main(true)
	main.show_boot()
	tap_action(main.get_viewport(), "ui_accept")
	await wait_process_frames(2)
	assert_eq((_focus_owner(main) as Button).text, "Collect", "the idle dialog has focus")
	tap_action(main.get_viewport(), "ui_accept")
	await wait_process_frames(2)
	assert_true(_focus_owner(main) is SlotCard, "the overview has focus again after Collect")


func test_boot_and_hint_start_with_a() -> void:
	var main := make_main()
	main.show_boot()
	tap_action(main.get_viewport(), "ui_accept")
	assert_true(main.screen is OverviewScreen)
	GameState.seen_tutorials = [] as Array[String]
	main.show_puzzle(SlotGenerator.make(1, SlotDef.TYPE_STO))
	assert_not_null(main.screen.hint)
	await wait_process_frames(2)  # the hint takes focus once the old screen is gone
	tap_action(main.get_viewport(), "ui_accept")
	assert_eq(main.screen.puzzle.phase, PuzzleBase.Phase.COUNTDOWN, "hint dismissed with A")


## "Again" on the result overlay hides the button that had focus; the new attempt must be
## playable with the gamepad, so its control gets the focus back.
func test_again_hands_focus_to_the_next_attempt() -> void:
	var screen: Control = await _puzzle_screen(1, SlotDef.TYPE_STO)
	var viewport: Viewport = screen.get_viewport()
	screen.puzzle.abort()
	screen.overlay.show_result("Write complete", "RAM", {})
	await wait_process_frames(2)
	assert_eq((_focus_owner(screen) as Button).text, "Again", "the overlay has focus")
	tap_action(viewport, "ui_accept")
	await wait_process_frames(2)
	assert_eq(_focus_owner(screen), screen.puzzle.default_focus(), "the puzzle has focus again")


func test_ram_cursor_becomes_visible_on_use() -> void:
	var screen: Control = await _puzzle_screen(1, SlotDef.TYPE_RAM)
	var grid: RamGrid = screen.puzzle.grid()
	assert_false(grid.has_focus(true), "hidden until a gamepad/keyboard press")
	tap_action(screen.get_viewport(), "ui_right")
	assert_true(grid.has_focus(true), "cursor outline shows")
