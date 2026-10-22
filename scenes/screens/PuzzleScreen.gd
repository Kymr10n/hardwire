class_name PuzzleScreen
extends Control
## Puzzle screen (SPEC: Screens and UX flow): header with minigame name, tier, modifier and back
## button; phase label; timer bar; the minigame area; result overlay.
## Owns the attempt loop: on failure it starts a fresh attempt at once; on success it credits the
## reward to GameState, saves and shows the overlay (puzzles never touch GameState).

signal exit_requested

## First-run instruction per minigame (SPEC: First run).
const HINTS := {
	SlotDef.TYPE_STO: "Repeat the sequence",
	SlotDef.TYPE_RAM: "Recreate the pattern",
	SlotDef.TYPE_CPU: "Copy the rhythm by holding the tile",
}

var slot: SlotDef
var puzzle: PuzzleBase
var hint: HintOverlay

var overlay: ResultOverlay
var bezel: Bezel
var _rng := RandomNumberGenerator.new()
var _phase_label: Label
var _status: ColorRect
var _blink: Tween
var _timer_bar: TimerBar


## Copies the current upgrade levels into the slot so assists apply (SPEC: Upgrade shop).
func setup(p_slot: SlotDef) -> void:
	slot = p_slot
	slot.assist = GameState.upgrades.duplicate()


func _ready() -> void:
	_rng.randomize()
	var landscape: bool = Ui.is_landscape(self)
	# Portrait: panel above the puzzle. Landscape: panel beside it.
	var body: BoxContainer = Ui.box(not landscape)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Ui.screen_root(self, 0.0, 1.0).add_child(body)
	body.add_child(_build_panel(landscape))
	bezel = Bezel.new()
	bezel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bezel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(bezel)
	puzzle = _new_puzzle(slot.type)
	bezel.add_child(puzzle)
	puzzle.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, bezel.inset()
	)
	puzzle.phase_changed.connect(_on_phase_changed)
	puzzle.solved.connect(_on_solved)
	puzzle.failed.connect(_on_failed)
	overlay = ResultOverlay.new()
	add_child(overlay)
	overlay.again_pressed.connect(start_attempt)
	overlay.overview_pressed.connect(go_back)
	if GameState.seen_tutorials.has(slot.type):
		start_attempt()
	else:
		hint = HintOverlay.new()
		hint.text = HINTS.get(slot.type, "")
		hint.dismissed.connect(_on_hint_dismissed)
		add_child(hint)


## Header (back + title), phase label and timer bar.
func _build_panel(landscape: bool) -> BoxContainer:
	var hue: Color = get_theme_color(slot.type, "Hardwire")
	var panel: BoxContainer = Ui.box(true)
	if landscape:
		panel.custom_minimum_size.x = get_theme_constant("side_panel", "Hardwire")
	var title: Label = Ui.header(panel, title_text(), go_back, landscape)
	title.add_theme_color_override("font_color", hue)
	# Status square (solid while watching, blinking while the player's turn runs) and phase label.
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", get_theme_constant("tag_pad", "Hardwire"))
	panel.add_child(status_row)
	_status = ColorRect.new()
	_status.custom_minimum_size = Vector2.ONE * get_theme_constant("lamp_size", "Hardwire")
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(_status)
	_phase_label = Ui.label("", get_theme_font_size("phase", "Hardwire"))
	_phase_label.uppercase = true
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_phase_label)
	_timer_bar = TimerBar.new()
	_timer_bar.color = hue
	_timer_bar.custom_minimum_size.y = get_theme_constant("timer_bar_height", "Hardwire")
	panel.add_child(_timer_bar)
	return panel


func _on_hint_dismissed() -> void:
	hint = null
	GameState.seen_tutorials.append(slot.type)
	SaveManager.save_game()
	start_attempt()


## The hint while it is up (A begins), else the puzzle's control.
func default_focus() -> Control:
	return hint if hint != null else puzzle.default_focus()


## Fresh sequence (new seed), same slot and difficulty. Hiding the overlay (or the hint going
## away) drops gamepad focus with it, so the puzzle's control takes it back.
func start_attempt() -> void:
	overlay.hide()
	puzzle.setup(slot, _rng.randi())
	puzzle.start()
	Ui.focus_first(self)


func _process(_delta: float) -> void:
	_timer_bar.value = puzzle.time_fraction()


## Header text: minigame, tier and the modifier name (SPEC: Puzzle screen).
func title_text() -> String:
	var text: String = "%s  T%d" % [SlotDef.TYPE_NAMES.get(slot.type, slot.type), slot.tier]
	if not slot.modifier.is_empty():
		text += "  [%s]" % SlotDef.modifier_name(slot.modifier)
	return text


## Countdown and Watch are dim; the active input phase and success are the accent; failure is red.
func _on_phase_changed(phase: PuzzleBase.Phase, text: String) -> void:
	_phase_label.text = text
	var color_name: String = "text_dim"
	if phase == PuzzleBase.Phase.INPUT:
		color_name = "accent"
	elif phase == PuzzleBase.Phase.RESULT:
		var corrupted: bool = text == "Corrupted"
		color_name = "fail" if corrupted else "accent"
		if corrupted:
			bezel.pulse(get_theme_color("fail", "Hardwire"))
	_phase_label.add_theme_color_override("font_color", get_theme_color(color_name, "Hardwire"))
	_status.color = get_theme_color(color_name, "Hardwire")
	if _blink:
		_blink.kill()
	_status.modulate.a = 1.0
	_status.visible = phase in [PuzzleBase.Phase.WATCH, PuzzleBase.Phase.INPUT]
	if phase == PuzzleBase.Phase.INPUT:
		_blink = Ui.blink(_status)


func _on_solved(_result: Dictionary) -> void:
	var gain: Dictionary = GameState.apply_solve(slot)
	SaveManager.save_game()
	bezel.pulse(get_theme_color("accent", "Hardwire"))
	overlay.show_result("Write complete", SlotDef.STAT_NAMES[slot.type], gain)


func _on_failed() -> void:
	GameState.record_fail()
	start_attempt()


## Back button (and Android back): abandon the attempt without penalty.
func go_back() -> void:
	puzzle.abort()
	exit_requested.emit()


static func _new_puzzle(type: String) -> PuzzleBase:
	match type:
		SlotDef.TYPE_STO:
			return StoragePuzzle.new()
		SlotDef.TYPE_RAM:
			return RamPuzzle.new()
	return CpuPuzzle.new()
