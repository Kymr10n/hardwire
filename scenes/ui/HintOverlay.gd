class_name HintOverlay
extends Control
## First-run instruction (SPEC: First run): one line over the puzzle; a tap dismisses it.

signal dismissed

var text: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(get_theme_color("bg", "Hardwire"), 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire"))
	add_child(box)
	var line := Label.new()
	line.text = text
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	box.add_child(line)
	var tap := Label.new()
	tap.text = "Tap or press A to begin"
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	box.add_child(tap)


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if (touch != null and not touch.pressed) or Ui.accept_event(event) == 1:
		get_viewport().set_input_as_handled()
		dismissed.emit()
		queue_free()
