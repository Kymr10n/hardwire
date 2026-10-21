class_name BootScreen
extends Control
## Boot screen (SPEC: Screens and UX flow): title, subtitle, a short check list from real state
## ending in "System ready", "Tap to start" and the version as a firmware line in the corner
## (D-035, D-039). The save is loaded by the SaveManager autoload before this screen exists. Any
## press starts the game at once, also while the list is still appearing.

signal start_requested

var prompt: Label
var version: Label
## The check list, one Label per line, created empty so the layout never shifts.
var lines: Array[Label] = []


func _ready() -> void:
	var box: VBoxContainer = Ui.centered_column(self)
	var parts: PackedStringArray = Ui.title_parts()
	box.add_child(Ui.label(parts[0].to_upper(), get_theme_font_size("title", "Hardwire") * 2))
	box.add_child(Ui.dim_label(parts[1].to_upper()))
	prompt = Ui.dim_label("")
	prompt.hide()
	box.add_child(_build_checks())
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


## Check lines from the real state, one per boot_line_ms; the last one is the accent "System ready".
## A save counts as new until the first solve (SPEC: Boot).
func check_texts() -> Array[String]:
	return [
		"New system" if GameState.lifetime.solves == 0 else "Save loaded",
		"Cores %d" % GameState.cores,
		"Best tier %d" % GameState.best_tier_ever,
		"System ready",
	]


func _build_checks() -> VBoxContainer:
	var column := VBoxContainer.new()
	var texts: Array[String] = check_texts()
	var tween: Tween = create_tween()
	var step: float = get_theme_constant("boot_line_ms", "Hardwire") / 1000.0
	for text: String in texts:
		var line: Label = Ui.dim_label("")
		line.uppercase = true
		line.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
		column.add_child(line)
		lines.append(line)
		tween.tween_interval(step)
		tween.tween_callback(line.set_text.bind(text))
	lines[-1].add_theme_color_override("font_color", get_theme_color("accent", "Hardwire"))
	tween.tween_callback(prompt.show)
	return column


## "Tap to start" on touch, "Press any button" otherwise (SPEC: Boot).
func _update_prompt(_device: int = 0) -> void:
	var touch: bool = InputMode.device == InputMode.Device.TOUCH
	prompt.text = "Tap to start" if touch else "Press any button"


func _input(event: InputEvent) -> void:
	if InputMode.is_any_press(event):
		get_viewport().set_input_as_handled()
		Haptics.pulse()
		start_requested.emit()
