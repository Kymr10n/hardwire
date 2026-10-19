class_name HintOverlay
extends Control
## First-run instruction (SPEC: First run): one line over the puzzle; a tap or A dismisses it.
## Takes focus so the accept action reaches it; the backdrop passes touches up to this control.

signal dismissed

var text: String = ""
var prompt: Label


func _init() -> void:
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	var box: VBoxContainer = Ui.centered_column(self, Ui.pct(self, "hint_dim_pct"))
	var line: Label = Ui.label(text, get_theme_font_size("header", "Hardwire"))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	prompt = Ui.dim_label("")
	box.add_child(prompt)
	InputMode.device_changed.connect(_update_prompt)
	_update_prompt()
	grab_focus.call_deferred(true)


func _update_prompt(_device: int = 0) -> void:
	prompt.text = InputMode.prompt("ui_accept", "begin")


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if (touch != null and not touch.pressed) or Ui.accept_event(event) == 1:
		accept_event()
		dismissed.emit()
		queue_free()
