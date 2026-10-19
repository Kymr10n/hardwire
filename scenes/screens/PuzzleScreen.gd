extends Control
## Puzzle screen (SPEC: Screens and UX flow): header with minigame name, tier, modifier and back
## button; phase label; timer bar; the minigame area; result overlay.
## Owns the attempt loop: on failure it starts a fresh attempt at once; on success it shows the overlay.
## Rewards are credited here from M5 on (puzzles never touch GameState).

signal exit_requested

const PUZZLES := {
	SlotDef.TYPE_STO: preload("res://scenes/puzzles/StoragePuzzle.gd"),
	SlotDef.TYPE_RAM: preload("res://scenes/puzzles/RamPuzzle.gd"),
}

var slot: SlotDef
var puzzle: PuzzleBase

var _rng := RandomNumberGenerator.new()
var _phase_label: Label
var _timer_bar: TimerBar
var _overlay: ResultOverlay


func setup(p_slot: SlotDef) -> void:
	slot = p_slot


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	var accent: Color = get_theme_color(slot.type, "Hardwire")
	var margin: int = get_theme_constant("margin", "Hardwire")

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + side, margin)
	add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", margin / 2)
	root.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", margin / 2)
	column.add_child(header)
	var back := Button.new()
	back.text = "< Back"
	back.custom_minimum_size = Vector2.ONE * get_theme_constant("tap_min", "Hardwire")
	back.pressed.connect(_on_back)
	header.add_child(back)
	var title := Label.new()
	title.text = _title_text()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", accent)
	title.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	header.add_child(title)

	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", get_theme_font_size("phase", "Hardwire"))
	column.add_child(_phase_label)

	_timer_bar = TimerBar.new()
	_timer_bar.color = accent
	_timer_bar.custom_minimum_size.y = get_theme_constant("timer_bar_height", "Hardwire")
	column.add_child(_timer_bar)

	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(area)
	puzzle = PUZZLES[slot.type].new() as PuzzleBase
	puzzle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(puzzle)
	puzzle.phase_changed.connect(_on_phase_changed)
	puzzle.solved.connect(_on_solved)
	puzzle.failed.connect(start_attempt)

	_overlay = ResultOverlay.new()
	add_child(_overlay)
	_overlay.again_pressed.connect(start_attempt)
	_overlay.overview_pressed.connect(_on_back)

	start_attempt()


## Fresh sequence (new seed), same slot and difficulty.
func start_attempt() -> void:
	_overlay.hide()
	puzzle.setup(slot, _rng.randi())
	puzzle.start()


func _process(_delta: float) -> void:
	_timer_bar.fraction = puzzle.time_fraction()


func _title_text() -> String:
	var text: String = "%s  T%d" % [SlotDef.TYPE_NAMES.get(slot.type, slot.type), slot.tier]
	if not slot.modifier.is_empty():
		text += "  [%s]" % slot.modifier.capitalize()
	return text


func _on_phase_changed(phase: PuzzleBase.Phase, text: String) -> void:
	_phase_label.text = text
	var color: Color = get_theme_color("text", "Hardwire")
	if phase == PuzzleBase.Phase.RESULT and text == "Corrupted":
		color = get_theme_color("fail", "Hardwire")
	_phase_label.add_theme_color_override("font_color", color)


func _on_solved(_result: Dictionary) -> void:
	_overlay.show_result("Write complete", "", get_theme_color(slot.type, "Hardwire"))


func _on_back() -> void:
	puzzle.abort()
	exit_requested.emit()
