class_name BootScreen
extends Control
## Boot screen (SPEC: Screens and UX flow): title fading in, subtitle, a check list typed from real
## state behind a block cursor with a tick per character, ending in "System ready", then "Tap to
## start"; the version as a firmware line in the corner (D-035, D-039, D-041). The save is loaded
## by the SaveManager autoload before this screen exists. Any press starts the game at once.

signal start_requested

## The memory checks, one per stat, with the dotted leader's width.
const CHECKS := {"ram": "Memory check", "cpu": "Clock", "sto": "Storage"}
const LEADER := 18

var prompt: Label
var version: Label
## The game name; fades in over the first typed line.
var title: Label
## The check list, one Label per line, created empty so the layout never shifts.
var lines: Array[Label] = []

var _typed: int = -1


func _ready() -> void:
	var box: VBoxContainer = Ui.centered_column(self)
	var parts: PackedStringArray = Ui.title_parts()
	title = Ui.label(parts[0].to_upper(), get_theme_font_size("title", "Hardwire") * 2)
	title.modulate.a = 0.0
	box.add_child(title)
	box.add_child(Ui.dim_label(parts[1].to_upper()))
	prompt = Ui.dim_label("")
	prompt.hide()
	var first_line_s: float = _build_checks(box)
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
	# The title comes up with the first line; the machine powers on.
	create_tween().tween_property(title, "modulate:a", 1.0, first_line_s)
	Synth.play_boot()


## Check lines from the real state; the last one is the accent "System ready". A save counts as
## new until the first solve (SPEC: Boot).
func check_texts() -> Array[String]:
	var stats: Dictionary = GameState.stats()
	var out: Array[String] = []
	for type: String in SlotGenerator.TYPES:
		var leader: String = (CHECKS[type] + " ").rpad(LEADER, ".")
		out.append("%s %s %d OK" % [leader, SlotDef.STAT_NAMES[type], stats[type]])
	out.append("Cores %d  Best tier %d" % [GameState.cores, GameState.best_tier_ever])
	out.append("New system" if GameState.lifetime.solves == 0 else "Save loaded")
	out.append("System ready")
	return out


## One tween types every line character by character (boot_char_ms each), then shows the prompt.
## Returns how long the first line takes.
func _build_checks(box: VBoxContainer) -> float:
	var column := VBoxContainer.new()
	box.add_child(column)
	var texts: Array[String] = check_texts()
	var tween: Tween = create_tween()
	var char_s: float = get_theme_constant("boot_char_ms", "Hardwire") / 1000.0
	for i: int in texts.size():
		var line: Label = Ui.dim_label("")
		line.uppercase = true
		line.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
		column.add_child(line)
		lines.append(line)
		tween.tween_method(
			_type.bind(i, texts[i]), 0, texts[i].length(), char_s * texts[i].length()
		)
	lines[-1].add_theme_color_override("font_color", get_theme_color("accent", "Hardwire"))
	tween.tween_callback(prompt.show)
	return char_s * texts[0].length()


## Shows the first `count` characters of line `i` behind the cursor; every other character ticks
## (one tick per character would be a buzz at boot_char_ms).
func _type(count: int, i: int, text: String) -> void:
	var done: bool = count >= text.length()
	lines[i].text = text.substr(0, count) + ("" if done else Ui.CURSOR)
	if count != _typed and count % 2 == 1:
		Synth.play_fx("tick")
	_typed = count


## "Tap to start" on touch, "Press any button" otherwise (SPEC: Boot).
func _update_prompt(_device: int = 0) -> void:
	var touch: bool = InputMode.device == InputMode.Device.TOUCH
	prompt.text = "Tap to start" if touch else "Press any button"


func _input(event: InputEvent) -> void:
	if InputMode.is_any_press(event):
		get_viewport().set_input_as_handled()
		Haptics.pulse()
		start_requested.emit()
