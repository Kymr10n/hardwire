extends Control
## Boot screen (SPEC: Screens and UX flow): title and "Tap to start". The save is loaded by the
## SaveManager autoload before this screen exists.

signal start_requested

var prompt: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire") * 2)
	add_child(box)
	var title := Label.new()
	title.text = "HARDWIRE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", get_theme_font_size("title", "Hardwire") * 2)
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
