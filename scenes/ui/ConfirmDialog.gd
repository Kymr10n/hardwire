class_name ConfirmDialog
extends Control
## Modal dialog over the whole screen, a face plate screwed over it (DESIGN: Panels): title strip,
## message, a confirm button and an optional cancel button. Frees itself after either button.
## `hazard` gives it the yellow-black striped frame (the Rebuild dialog only).

signal confirmed
signal cancelled

## The striped frame; set right after open().
var hazard: bool = false:
	set(value):
		hazard = value
		if _panel:
			_panel.add_theme_stylebox_override("panel", get_theme_stylebox("hazard", "Hardwire"))

var _panel: PanelContainer
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
	_panel = box.get_parent()
	if hazard:
		hazard = true
	var title: Label = Ui.label(_title, get_theme_font_size("header", "Hardwire"))
	title.uppercase = true
	var rule := StyleBoxFlat.new()
	rule.draw_center = false
	rule.border_width_bottom = 1
	rule.border_color = get_theme_color("text_dim", "Hardwire")
	title.add_theme_stylebox_override("normal", rule)
	box.add_child(title)
	var message: Label = Ui.label(_message)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire"))
	box.add_child(buttons)
	if not _cancel_text.is_empty():
		buttons.add_child(Ui.button(_cancel_text, cancel, true))
	var ok: Button = Ui.button(_confirm_text, confirm, true)
	buttons.add_child(ok)
	ok.grab_focus.call_deferred(true)


## B / Esc cancels when the dialog has a cancel button.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _cancel_text.is_empty():
			cancel()


func confirm() -> void:
	confirmed.emit()
	queue_free()


func cancel() -> void:
	cancelled.emit()
	queue_free()
