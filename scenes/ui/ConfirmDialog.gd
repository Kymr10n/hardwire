class_name ConfirmDialog
extends Control
## Modal dialog over the whole screen: title, message, a confirm button and an optional cancel button.
## Frees itself after either button.

signal confirmed
signal cancelled

var _title: String
var _message: String
var _confirm_text: String
var _cancel_text: String


## cancel_text = "" shows only the confirm button.
static func open(parent: Node, title: String, message: String, confirm_text: String, cancel_text: String = "Cancel") -> ConfirmDialog:
	var dialog := ConfirmDialog.new()
	dialog._title = title
	dialog._message = message
	dialog._confirm_text = confirm_text
	dialog._cancel_text = cancel_text
	parent.add_child(dialog)
	return dialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(get_theme_color("bg", "Hardwire"), 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 860
	center.add_child(panel)
	var margin: int = get_theme_constant("margin", "Hardwire")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", margin)
	panel.add_child(box)
	var title := Label.new()
	title.text = _title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	box.add_child(title)
	var message := Label.new()
	message.text = _message
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", margin)
	box.add_child(buttons)
	var tap: float = get_theme_constant("tap_min", "Hardwire")
	if not _cancel_text.is_empty():
		var cancel := Button.new()
		cancel.text = _cancel_text
		cancel.custom_minimum_size = Vector2(tap * 2.5, tap)
		cancel.pressed.connect(_close.bind(false))
		buttons.add_child(cancel)
	var ok := Button.new()
	ok.text = _confirm_text
	ok.custom_minimum_size = Vector2(tap * 2.5, tap)
	ok.pressed.connect(_close.bind(true))
	buttons.add_child(ok)
	ok.grab_focus.call_deferred(true)


## B / Esc cancels when the dialog has a cancel button.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _cancel_text.is_empty():
			_close(false)


func _close(ok: bool) -> void:
	if ok:
		confirmed.emit()
	else:
		cancelled.emit()
	queue_free()
