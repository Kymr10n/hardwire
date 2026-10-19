class_name ConfirmDialog
extends Control
## Modal dialog over the whole screen: title, message, a confirm button and an optional cancel
## button. Frees itself after either button.

signal confirmed
signal cancelled

var _title: String
var _message: String
var _confirm_text: String
var _cancel_text: String


## cancel_text = "" shows only the confirm button.
static func open(
	parent: Node,
	title: String,
	message: String,
	confirm_text: String,
	cancel_text: String = "Cancel"
) -> ConfirmDialog:
	var dialog := ConfirmDialog.new()
	dialog._title = title
	dialog._message = message
	dialog._confirm_text = confirm_text
	dialog._cancel_text = cancel_text
	parent.add_child(dialog)
	return dialog


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box: VBoxContainer = Ui.modal(
		self, Ui.pct(self, "dialog_dim_pct"), get_theme_constant("dialog_width", "Hardwire")
	)
	box.add_child(Ui.label(_title, get_theme_font_size("header", "Hardwire")))
	var message: Label = Ui.label(_message)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire"))
	box.add_child(buttons)
	if not _cancel_text.is_empty():
		buttons.add_child(Ui.button(_cancel_text, _close.bind(false), true))
	var ok: Button = Ui.button(_confirm_text, _close.bind(true), true)
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
