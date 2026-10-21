extends "res://tests/hardwire_test.gd"
## Glyphs for the last-used device (SPEC: Platforms and input > Glyphs, D-021).


func _touch(emulated: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.device = InputEvent.DEVICE_ID_EMULATION if emulated else 0
	return event


func _pad_button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _use(event: InputEvent) -> void:
	InputMode._input(event)


func test_device_from_events() -> void:
	assert_eq(InputMode.device_of(_touch(false)), InputMode.Device.TOUCH)
	assert_eq(InputMode.device_of(_touch(true)), InputMode.Device.KEYBOARD_MOUSE, "mouse")
	assert_eq(InputMode.device_of(InputEventKey.new()), InputMode.Device.KEYBOARD_MOUSE)
	assert_eq(InputMode.device_of(_pad_button(JOY_BUTTON_A)), InputMode.Device.GAMEPAD)
	var small := InputEventJoypadMotion.new()
	small.axis_value = 0.2
	assert_eq(InputMode.device_of(small), -1, "stick noise is ignored")
	assert_eq(InputMode.device_of(InputEventAction.new()), -1)


func test_device_changed_is_emitted_once() -> void:
	_use(InputEventKey.new())
	watch_signals(InputMode)
	_use(_pad_button(JOY_BUTTON_A))
	_use(_pad_button(JOY_BUTTON_B))
	assert_signal_emit_count(InputMode, "device_changed", 1)
	assert_eq(InputMode.device, InputMode.Device.GAMEPAD)


func test_glyphs_follow_the_device() -> void:
	_use(_pad_button(JOY_BUTTON_A))
	assert_eq(InputMode.glyph("ui_accept"), "A")
	assert_eq(InputMode.glyph("commit"), "Y")
	assert_eq(InputMode.prompt("ui_accept", "begin"), "Press A to begin")
	_use(InputEventKey.new())
	assert_eq(InputMode.glyph("ui_accept"), "Enter")
	assert_eq(InputMode.glyph("commit"), "C")
	assert_eq(InputMode.prompt("ui_accept", "begin"), "Click or press Enter to begin")
	_use(_touch(false))
	assert_eq(InputMode.glyph("ui_accept"), "")
	assert_eq(InputMode.prompt("ui_accept", "begin"), "Tap to begin")


func test_boot_prompt_and_any_press() -> void:
	_use(_touch(false))
	var boot: Control = BootScreen.new()
	add_child_autofree(boot)
	assert_eq(boot.prompt.text, "Tap to start")
	_use(_pad_button(JOY_BUTTON_A))
	assert_eq(boot.prompt.text, "Press any button", "updates when the device changes")
	watch_signals(boot)
	boot._input(_pad_button(JOY_BUTTON_X))
	assert_signal_emitted(boot, "start_requested", "any gamepad button starts")


## D-039/D-041: the check list is typed from the real state, the title fades in with the first
## line, and a press before it is complete still starts the game.
func test_boot_check_list_and_early_skip() -> void:
	GameState.cores = 2
	GameState.best_tier_ever = 12
	GameState.lifetime.solves = 5
	var boot: Control = BootScreen.new()
	add_child_autofree(boot)
	GameState.add_stats(140, 131, 136)
	var texts: Array[String] = boot.check_texts()
	assert_eq(texts.size(), 6)
	assert_true(texts[0].begins_with("Memory check ..") and texts[0].ends_with(" RAM 140 OK"))
	assert_true(texts[1].ends_with(" CPU 131 OK") and texts[2].ends_with(" STO 136 OK"))
	assert_eq(texts.slice(3), ["Cores 2  Best tier 12", "Save loaded", "System ready"])
	assert_eq(boot.lines.size(), 6)
	assert_true(boot.lines[0].text.length() <= 1, "typing has barely begun")
	assert_eq(boot.title.modulate.a, 0.0, "title fades in")
	assert_false(boot.prompt.visible)
	watch_signals(boot)
	boot._input(_pad_button(JOY_BUTTON_A))
	assert_signal_emitted(boot, "start_requested", "a press mid-list starts at once")
	var char_s: float = (
		ThemeDB.get_project_theme().get_constant("boot_char_ms", "Hardwire") / 1000.0
	)
	var chars: int = 0
	for text: String in texts:
		chars += text.length()
	await wait_seconds(char_s * chars + 0.2)
	assert_eq(boot.lines[5].text, "System ready", "typed out, cursor gone")
	assert_true(boot.prompt.visible)
	assert_eq(boot.title.modulate.a, 1.0)
	GameState.reset_all()
	var fresh: Control = BootScreen.new()
	add_child_autofree(fresh)
	assert_eq(fresh.check_texts()[4], "New system")


## D-035: the version from project.godot sits in the bottom-right corner.
func test_boot_shows_the_version_in_the_corner() -> void:
	var boot: Control = in_viewport(BootScreen.new(), Vector2i(1080, 1920))
	await wait_process_frames(2)
	assert_eq(
		boot.version.text,
		"FIRMWARE v%s" % ProjectSettings.get_setting("application/config/version")
	)
	var rect: Rect2 = boot.version.get_global_rect()
	var view: Rect2 = boot.get_viewport().get_visible_rect()
	assert_true(view.encloses(rect), "on screen")
	assert_gt(rect.position.x, view.size.x / 2.0, "right half")
	assert_gt(rect.position.y, view.size.y * 0.8, "bottom")


func test_ram_commit_shows_glyph() -> void:
	var puzzle: PuzzleBase = RamPuzzle.new()
	add_child_autofree(puzzle)
	_use(_pad_button(JOY_BUTTON_A))
	assert_eq(puzzle.commit_button.text, "Commit (Y)")
	_use(_touch(false))
	assert_eq(puzzle.commit_button.text, "Commit")


func test_debug_panel_action_opens_panel() -> void:
	var main: Node = make_main()
	main.show_overview()
	await wait_process_frames(2)
	tap_action(main.get_viewport(), "debug_panel")
	assert_true(main.screen is DebugMenu)


func test_backspace_is_back() -> void:
	var codes: Array[Key] = []
	for event: InputEvent in InputMap.action_get_events("ui_cancel"):
		if event is InputEventKey:
			codes.append(event.keycode)
	assert_has(codes, KEY_BACKSPACE)
	assert_has(codes, KEY_ESCAPE)


func test_theme_fonts_are_at_least_32_px() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	assert_gte(theme.default_font_size, 32)
	for type: StringName in theme.get_font_size_type_list():
		for name: StringName in theme.get_font_size_list(type):
			assert_gte(theme.get_font_size(name, type), 32, "%s/%s" % [type, name])
