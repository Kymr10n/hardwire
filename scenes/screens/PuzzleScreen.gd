extends Control
## Puzzle screen (SPEC: Screens and UX flow): header with minigame name, tier, modifier and back
## button; phase label; timer bar; the minigame area; result overlay.
## Owns the attempt loop: on failure it starts a fresh attempt at once; on success it credits the
## reward to GameState, saves and shows the overlay (puzzles never touch GameState).

signal exit_requested

const PUZZLES := {
	SlotDef.TYPE_STO: preload("res://scenes/puzzles/StoragePuzzle.gd"),
	SlotDef.TYPE_RAM: preload("res://scenes/puzzles/RamPuzzle.gd"),
	SlotDef.TYPE_CPU: preload("res://scenes/puzzles/CpuPuzzle.gd"),
}

## First-run instruction per minigame (SPEC: First run).
const HINTS := {
	SlotDef.TYPE_STO: "Repeat the sequence",
	SlotDef.TYPE_RAM: "Recreate the pattern",
	SlotDef.TYPE_CPU: "Copy the rhythm by holding the tile",
}

var slot: SlotDef
var puzzle: PuzzleBase
var hint: HintOverlay

var _rng := RandomNumberGenerator.new()
var _phase_label: Label
var _timer_bar: TimerBar
var _overlay: ResultOverlay


## Copies the current upgrade levels into the slot so assists apply (SPEC: Upgrade shop).
func setup(p_slot: SlotDef) -> void:
	slot = p_slot
	slot.assist = GameState.upgrades.duplicate()


func _ready() -> void:
	_rng.randomize()
	var accent: Color = get_theme_color(slot.type, "Hardwire")
	var landscape: bool = Ui.is_landscape(self)
	var root: VBoxContainer = Ui.screen_root(self, 0.0, 1.0)

	# Portrait: panel above the puzzle. Landscape: panel beside it.
	var body := BoxContainer.new()
	body.vertical = not landscape
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire") / 2)
	root.add_child(body)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire") / 2)
	if landscape:
		panel.custom_minimum_size.x = get_theme_constant("side_panel", "Hardwire")
	body.add_child(panel)

	var title: Label = Ui.header(panel, _title_text(), go_back, landscape)
	title.add_theme_color_override("font_color", accent)

	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", get_theme_font_size("phase", "Hardwire"))
	panel.add_child(_phase_label)

	_timer_bar = TimerBar.new()
	_timer_bar.color = accent
	_timer_bar.custom_minimum_size.y = get_theme_constant("timer_bar_height", "Hardwire")
	panel.add_child(_timer_bar)

	var area := Control.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(area)
	puzzle = PUZZLES[slot.type].new() as PuzzleBase
	puzzle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(puzzle)
	puzzle.phase_changed.connect(_on_phase_changed)
	puzzle.solved.connect(_on_solved)
	puzzle.failed.connect(_on_failed)

	_overlay = ResultOverlay.new()
	add_child(_overlay)
	_overlay.again_pressed.connect(start_attempt)
	_overlay.overview_pressed.connect(go_back)

	if GameState.seen_tutorials.has(slot.type):
		start_attempt()
	else:
		hint = HintOverlay.new()
		hint.text = HINTS.get(slot.type, "")
		hint.dismissed.connect(_on_hint_dismissed)
		add_child(hint)


func _on_hint_dismissed() -> void:
	hint = null
	GameState.seen_tutorials.append(slot.type)
	SaveManager.save_game()
	start_attempt()


func default_focus() -> Control:
	return puzzle.default_focus()


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
	var gain: Dictionary = GameState.apply_solve(slot)
	SaveManager.save_game()
	_overlay.show_result("Write complete", get_theme_color(slot.type, "Hardwire"), SlotDef.STAT_NAMES[slot.type], gain)


func _on_failed() -> void:
	GameState.record_fail()
	start_attempt()


## Back button (and Android back): abandon the attempt without penalty.
func go_back() -> void:
	puzzle.abort()
	exit_requested.emit()
