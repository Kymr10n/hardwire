extends Control
## Boot screen (SPEC: Screens and UX flow): title and "Tap to start". The save is loaded by the
## SaveManager autoload before this screen exists.

signal start_requested


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
	var hint := Label.new()
	hint.text = "Tap to start"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	box.add_child(hint)


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and not touch.pressed:
		get_viewport().set_input_as_handled()
		start_requested.emit()
