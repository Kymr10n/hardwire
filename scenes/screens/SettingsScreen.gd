extends Control
## Settings (SPEC: Screens and UX flow): sound on/off, haptics on/off, licenses, reset save
## (with confirm); on PC also Fullscreen and Quit. Saves after every change.

signal exit_requested
signal licenses_requested

var _sound: Button
var _haptics: Button
var _fullscreen: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: int = get_theme_constant("margin", "Hardwire")
	var tap: float = get_theme_constant("tap_min", "Hardwire")
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + side, margin)
	add_child(root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", margin)
	root.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var back := Button.new()
	back.text = "< Back"
	back.custom_minimum_size = Vector2(tap * 1.5, tap)
	back.pressed.connect(exit_requested.emit)
	header.add_child(back)
	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	header.add_child(title)

	_sound = _add_button(box, _toggle_setting.bind("sound"))
	_haptics = _add_button(box, _toggle_setting.bind("haptics"))
	var licenses := Button.new()
	licenses.text = "Licenses"
	licenses.custom_minimum_size.y = tap
	licenses.pressed.connect(licenses_requested.emit)
	box.add_child(licenses)
	if OS.has_feature("pc"):
		_fullscreen = _add_button(box, _toggle_fullscreen)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var reset := Button.new()
	reset.text = "Reset save"
	reset.custom_minimum_size.y = tap
	reset.add_theme_color_override("font_color", get_theme_color("fail", "Hardwire"))
	reset.pressed.connect(_on_reset)
	box.add_child(reset)
	if OS.has_feature("pc"):
		var quit := _add_button(box, _on_quit)
		quit.text = "Quit"
	_refresh()


func _add_button(parent: Control, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = get_theme_constant("tap_min", "Hardwire")
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _refresh() -> void:
	_sound.text = "Sound: %s" % ("On" if GameState.settings.sound else "Off")
	_haptics.text = "Haptics: %s" % ("On" if GameState.settings.haptics else "Off")
	if _fullscreen:
		_fullscreen.text = "Fullscreen: %s" % ("On" if _is_fullscreen() else "Off")


func _is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


func _toggle_fullscreen() -> void:
	get_window().mode = Window.MODE_WINDOWED if _is_fullscreen() else Window.MODE_FULLSCREEN
	_refresh()


func _on_quit() -> void:
	SaveManager.save_game()
	get_tree().quit()


func _toggle_setting(key: String) -> void:
	GameState.settings[key] = not GameState.settings[key]
	if key == "sound" and not GameState.settings.sound:
		Synth.stop_all()
	SaveManager.save_game()
	_refresh()


func _on_reset() -> void:
	var dialog := ConfirmDialog.open(self, "Reset save?", "All progress, Cores and statistics will be erased.", "Erase")
	dialog.confirmed.connect(func() -> void:
		GameState.reset_all()
		SaveManager.save_game()
		_refresh())
