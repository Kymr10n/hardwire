class_name SettingsScreen
extends Control
## Settings (SPEC: Screens and UX flow): sound on/off, haptics on/off, licenses, reset save
## (with confirm); on PC also Fullscreen. Saves after every change.

signal exit_requested
signal licenses_requested

var _sound: Button
var _haptics: Button
var _fullscreen: Button


func _ready() -> void:
	var box: VBoxContainer = Ui.screen_root(self, get_theme_constant("max_column", "Hardwire"), 1.0)
	Ui.header(box, "Settings", exit_requested.emit)

	# One column in portrait, two in landscape; destructive actions at the bottom.
	var options: GridContainer = _grid(box)
	_sound = _add_button(options, "", _toggle_setting.bind("sound"))
	_haptics = _add_button(options, "", _toggle_setting.bind("haptics"))
	_add_button(options, "Licenses", licenses_requested.emit)
	if OS.has_feature("pc"):
		_fullscreen = _add_button(options, "", _toggle_fullscreen)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var actions: GridContainer = _grid(box)
	var reset: Button = _add_button(actions, "Reset save", _on_reset)
	reset.add_theme_color_override("font_color", get_theme_color("fail", "Hardwire"))
	box.add_child(Ui.sticker(Ui.FINE_PRINT))
	_refresh()


func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2 if Ui.is_landscape(self) else 1
	var gap: int = get_theme_constant("margin", "Hardwire")
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	parent.add_child(grid)
	return grid


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button: Button = Ui.button(text, on_pressed)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button


func _refresh() -> void:
	_sound.text = "SOUND: %s" % _state(GameState.settings.sound)
	_haptics.text = "HAPTICS: %s" % _state(GameState.settings.haptics)
	if _fullscreen:
		_fullscreen.text = "FULLSCREEN: %s" % _state(_is_fullscreen())


static func _state(on: bool) -> String:
	return "ON" if on else "OFF"


func _is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


func _toggle_fullscreen() -> void:
	get_window().mode = Window.MODE_WINDOWED if _is_fullscreen() else Window.MODE_FULLSCREEN
	_refresh()


func _toggle_setting(key: String) -> void:
	GameState.settings[key] = not GameState.settings[key]
	if key == "sound" and not GameState.settings.sound:
		Synth.stop_all()
	SaveManager.save_game()
	_refresh()


func _on_reset() -> void:
	var dialog := ConfirmDialog.open(
		self, "Reset save?", "All progress, Cores and statistics will be erased.", "Erase"
	)
	dialog.confirmed.connect(
		func() -> void:
			GameState.reset_all()
			SaveManager.save_game()
			_refresh()
	)
