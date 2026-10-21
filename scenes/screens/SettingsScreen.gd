class_name SettingsScreen
extends Control
## Settings (SPEC: Screens and UX flow): sound on/off, haptics on/off, CRT glass on/off, licenses,
## reset save (with confirm); on PC also Fullscreen. Saves after every change.

signal exit_requested
signal licenses_requested

var _sound: Button
var _haptics: Button
var _crt: Button
var _fullscreen: Button


func _ready() -> void:
	var box: VBoxContainer = Ui.screen_root(self, get_theme_constant("max_column", "Hardwire"), 1.0)
	Ui.header(box, "Settings", exit_requested.emit)

	# One column in portrait, two in landscape; destructive actions at the bottom.
	var options: GridContainer = _grid(box)
	_sound = _add_button(options, "", _toggle_setting.bind("sound"))
	_haptics = _add_button(options, "", _toggle_setting.bind("haptics"))
	_crt = _add_button(options, "", _toggle_setting.bind("crt"))
	_add_button(options, "Licenses", licenses_requested.emit)
	if OS.has_feature("pc"):
		_fullscreen = _add_button(options, "", _toggle_fullscreen)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var actions: GridContainer = _grid(box)
	var reset: Button = _add_button(actions, "Reset save", _on_reset)
	Ui.tint(reset, get_theme_color("fail", "Hardwire"))
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
	_sound.text = "Sound: %s" % ("On" if GameState.settings.sound else "Off")
	_haptics.text = "Haptics: %s" % ("On" if GameState.settings.haptics else "Off")
	_crt.text = "CRT glass: %s" % ("On" if GameState.settings.crt else "Off")
	if _fullscreen:
		_fullscreen.text = "Fullscreen: %s" % ("On" if _is_fullscreen() else "Off")


func _is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]


func _toggle_fullscreen() -> void:
	get_window().mode = Window.MODE_WINDOWED if _is_fullscreen() else Window.MODE_FULLSCREEN
	_refresh()


func _toggle_setting(key: String) -> void:
	GameState.set_setting(key, not GameState.settings[key])
	if key == "sound" and not GameState.settings.sound:
		Synth.stop_all()
	SaveManager.save_game()
	_refresh()


func _on_reset() -> void:
	var dialog := ConfirmDialog.open(
		self, "Reset save?", "All progress, Cores and statistics will be erased.", "Erase"
	)
	Ui.tint(dialog.confirm_button, get_theme_color("fail", "Hardwire"))
	Ui.tag(dialog.title_label, get_theme_color("fail", "Hardwire"))
	dialog.confirmed.connect(
		func() -> void:
			GameState.reset_all()
			SaveManager.save_game()
			_refresh()
	)
