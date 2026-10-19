class_name BootScreen
extends Control
## Boot screen (SPEC: Screens and UX flow): title and "Tap to start". The save is loaded by the
## SaveManager autoload before this screen exists.

signal start_requested

var prompt: Label


func _ready() -> void:
	var box: VBoxContainer = Ui.centered_column(self)
	var title: Label = Ui.label("HARDWIRE", get_theme_font_size("title", "Hardwire") * 2)
	title.add_theme_color_override("font_color", get_theme_color("ram", "Hardwire"))
	box.add_child(title)
	prompt = Ui.dim_label("")
	box.add_child(prompt)
	InputMode.device_changed.connect(_update_prompt)
	_update_prompt()


## "Tap to start" on touch, "Press any button" otherwise (SPEC: Boot).
func _update_prompt(_device: int = 0) -> void:
	var touch: bool = InputMode.device == InputMode.Device.TOUCH
	prompt.text = "Tap to start" if touch else "Press any button"


func _input(event: InputEvent) -> void:
	if InputMode.is_any_press(event):
		get_viewport().set_input_as_handled()
		start_requested.emit()
