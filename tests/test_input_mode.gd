extends "res://tests/hardwire_test.gd"
## Glyphs for the last-used device (SPEC: Platforms and input > Glyphs, D-021).

const BootScreen := preload("res://scenes/screens/BootScreen.gd")
const RamPuzzle := preload("res://scenes/puzzles/RamPuzzle.gd")
const Main := preload("res://scenes/Main.tscn")
const DebugMenu := preload("res://scenes/screens/DebugMenu.gd")


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


func test_ram_commit_shows_glyph() -> void:
	var puzzle: PuzzleBase = RamPuzzle.new()
	add_child_autofree(puzzle)
	_use(_pad_button(JOY_BUTTON_A))
	assert_eq(puzzle._commit.text, "Commit (Y)")
	_use(_touch(false))
	assert_eq(puzzle._commit.text, "Commit")


func test_debug_panel_action_opens_panel() -> void:
	var main: Node = Main.instantiate()
	main._idle_check_pending = false
	add_child_autofree(main)
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
