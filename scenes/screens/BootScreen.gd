class_name BootScreen
extends Control
## Boot screen (SPEC: Screens and UX flow): title, subtitle, "Tap to start" and the version as a
## firmware line in the corner (D-035). The save is loaded by the SaveManager autoload before this
## screen exists.

signal start_requested

var prompt: Label
var version: Label


func _ready() -> void:
	var box: VBoxContainer = Ui.centered_column(self)
	# The name lives once, in project.godot: "Title: Subtitle".
	var game_name: String = ProjectSettings.get_setting("application/config/name")
	var font_size: int = get_theme_font_size("title", "Hardwire")
	var title: Label = Ui.label(game_name.get_slice(": ", 0).to_upper(), font_size * 2)
	title.add_theme_font_override("font", get_theme_font("title", "Hardwire"))
	box.add_child(title)
	var subtitle: Label = Ui.dim_label(game_name.get_slice(": ", 1).to_upper())
	subtitle.add_theme_font_size_override("font_size", font_size)
	box.add_child(subtitle)
	prompt = Ui.dim_label("")
	box.add_child(prompt)
	InputMode.device_changed.connect(_update_prompt)
	_update_prompt()
	version = Ui.dim_label(
		"FIRMWARE v%s" % ProjectSettings.get_setting("application/config/version")
	)
	version.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
	add_child(version)
	version.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT,
		Control.PRESET_MODE_MINSIZE,
		get_theme_constant("margin", "Hardwire")
	)


## "Tap to start" on touch, "Press any button" otherwise (SPEC: Boot).
func _update_prompt(_device: int = 0) -> void:
	var touch: bool = InputMode.device == InputMode.Device.TOUCH
	prompt.text = "Tap to start" if touch else "Press any button"


func _input(event: InputEvent) -> void:
	if InputMode.is_any_press(event):
		get_viewport().set_input_as_handled()
		Haptics.pulse()
		start_requested.emit()
