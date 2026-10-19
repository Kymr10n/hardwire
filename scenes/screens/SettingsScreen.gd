extends Control
## Settings (SPEC: Screens and UX flow): sound on/off, haptics on/off, reset save (with confirm).
## Saves after every change.

signal exit_requested

var _sound: Button
var _haptics: Button


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

	_sound = _toggle(box, _toggle_setting.bind("sound"))
	_haptics = _toggle(box, _toggle_setting.bind("haptics"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var reset := Button.new()
	reset.text = "Reset save"
	reset.custom_minimum_size.y = tap
	reset.add_theme_color_override("font_color", get_theme_color("fail", "Hardwire"))
	reset.pressed.connect(_on_reset)
	box.add_child(reset)
	_refresh()


func _toggle(parent: Control, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = get_theme_constant("tap_min", "Hardwire")
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


func _refresh() -> void:
	_sound.text = "Sound: %s" % ("On" if GameState.settings.sound else "Off")
	_haptics.text = "Haptics: %s" % ("On" if GameState.settings.haptics else "Off")


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
