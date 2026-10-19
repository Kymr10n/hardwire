class_name ResultOverlay
extends Control
## Success overlay over the puzzle area: title, detail text, "Again" and "Overview" buttons.
## (Failure needs no overlay: the puzzle reveals the answer and the next attempt starts.)

signal again_pressed
signal overview_pressed

var _title: Label
var _detail: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(get_theme_color("bg", "Hardwire"), 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire"))
	panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", get_theme_font_size("phase", "Hardwire"))
	box.add_child(_title)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire"))
	box.add_child(buttons)
	buttons.add_child(_button("Again", again_pressed.emit))
	buttons.add_child(_button("Overview", overview_pressed.emit))
	hide()


func show_result(title: String, detail: String, accent: Color) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", accent)
	_detail.text = detail
	_detail.visible = not detail.is_empty()
	show()


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	var tap: float = get_theme_constant("tap_min", "Hardwire")
	button.custom_minimum_size = Vector2(tap * 3.0, tap)
	button.pressed.connect(on_pressed)
	return button
