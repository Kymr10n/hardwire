class_name RamPuzzle
extends PuzzleBase
## RAM minigame: recreate the grid pattern. SPEC: Minigame: RAM.
## The pattern shows for show_ms, then the player toggles cells and presses Commit once the
## set count equals the cells needed. A wrong Commit or the timeout fails the attempt.

## Layout, in units of margin.
const WIDE_MARGINS := 3.0
## Rotation arrow, as fractions of tap_min and of its radius.
const ICON_RADIUS := 0.3
const ARROW_START := -PI * 0.75
const ARROW_SWEEP := PI * 1.5
const ARROW_WIDTH := 0.28
const ARROW_HEAD_HALF := 0.6
const ARROW_HEAD_LENGTH := 0.8
const ARC_SEGMENTS := 32

## One-line modifier hints above the grid (SPEC: Modifier hints).
const HINTS := {GridGen.MOD_INVERTED: "Set the dark cells", GridGen.MOD_ROTATED: "Enter it rotated"}

var hint: Label

var commit_button: Button
var _attempt: Dictionary = {}
var _grid: RamGrid
var _counter: Label
var _shown: bool = false
var _icon_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	hint = Ui.dim_label("")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	_grid = RamGrid.new()
	_grid.cell_activated.connect(toggle_cell)
	add_child(_grid)
	_counter = Label.new()
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	add_child(_counter)
	commit_button = Button.new()
	commit_button.pressed.connect(commit)
	add_child(commit_button)
	InputMode.device_changed.connect(_updatecommit_button_text)
	_updatecommit_button_text()
	resized.connect(_layout)
	_layout()


func expected() -> Array[int]:
	return _attempt.get("expected", [] as Array[int])


func pattern() -> Array[int]:
	return _attempt.get("pattern", [] as Array[int])


func grid() -> RamGrid:
	return _grid


## "Commit", plus the key or button for it when not on touch ("Commit (Y)").
func _updatecommit_button_text(_device: int = 0) -> void:
	var glyph: String = InputMode.glyph("commit")
	commit_button.text = "Commit" if glyph.is_empty() else "Commit (%s)" % glyph


func can_commit() -> bool:
	return phase == Phase.INPUT and _grid.on_cells().size() == expected().size()


## Toggles one cell during the input phase (from the grid's `cell_activated`; public for tests).
func toggle_cell(i: int) -> void:
	if phase != Phase.INPUT or i < 0 or i >= _grid.n * _grid.n:
		return
	_grid.set_on(i, not _grid.is_on(i))
	Synth.play_fx("click")
	Haptics.pulse()
	_update_counter()


## Checks the grid (Commit button; public for tests). Ignored until the set count is right.
func commit() -> void:
	if not can_commit():
		return
	if _grid.on_cells() == expected():
		_succeed({"slot_id": slot.id()})
	else:
		_fail()


func default_focus() -> Control:
	return _grid


func _input(event: InputEvent) -> void:
	if phase == Phase.INPUT and event.is_action_pressed("commit"):
		get_viewport().set_input_as_handled()
		commit()


func _build_attempt() -> void:
	_attempt = GridGen.make(slot, attempt_seed)
	time_limit_s = _attempt.time_limit_s
	_shown = false
	_grid.setup(_attempt.n)
	hint.text = HINTS.get(slot.modifier, "")
	queue_redraw()
	_update_counter()
	_layout()


## The controller rumbles while the pattern shows (D-034).
func _watch_update(t: float) -> bool:
	if t < _attempt.show_ms / 1000.0:
		if not _shown:
			_shown = true
			_grid.show_only(pattern())
			Haptics.start_hold()
		return false
	_grid.show_only([] as Array[int])
	Haptics.stop_hold()
	return true


func _on_phase_entered(_p_phase: Phase) -> void:
	_update_counter()


func _on_fail_reveal() -> void:
	_grid.show_only(expected())
	_update_counter()


func _on_abort() -> void:
	Haptics.stop_hold()
	_update_counter()


func _update_counter() -> void:
	var input: bool = phase == Phase.INPUT
	_counter.visible = input
	commit_button.visible = input or phase == Phase.RESULT
	commit_button.disabled = not can_commit()
	_counter.text = "%d / %d" % [_grid.on_cells().size(), expected().size()]


## Tall area: hint row (and rotation icon) on top, square grid, counter and Commit below.
## Wide area (landscape): grid on the left using the full height, a column with icon, hint,
## counter and Commit on the right, so cells stay at least 120 px.
func _layout() -> void:
	if _grid == null:
		return
	var margin: float = get_theme_constant("margin", "Hardwire")
	var row_h: float = get_theme_constant("tap_min", "Hardwire")
	var commit_w: float = get_theme_constant("button_width", "Hardwire")
	var wide: bool = size.x - WIDE_MARGINS * margin - commit_w > size.y - 2.0 * row_h - 2.0 * margin
	var side: float
	if wide:
		side = maxf(0.0, minf(size.y - 2.0 * margin, size.x - WIDE_MARGINS * margin - commit_w))
		var left: float = (size.x - side - margin - commit_w) / 2.0
		var top: float = (size.y - side) / 2.0
		var column_x: float = left + side + margin
		_grid.position = Vector2(left, top)
		_icon_center = Vector2(column_x + row_h * ICON_RADIUS, top + row_h / 2.0)
		hint.position = Vector2(column_x, top + row_h)
		hint.size = Vector2(commit_w, row_h * 2.0)
		commit_button.position = Vector2(column_x, top + side - row_h)
		_counter.position = Vector2(column_x, commit_button.position.y - row_h - margin / 2.0)
		_counter.size = Vector2(commit_w, row_h)
	else:
		side = maxf(0.0, minf(size.x - 2.0 * margin, size.y - 2.0 * row_h - 2.0 * margin))
		var top: float = maxf(row_h + margin, (size.y - side) / 2.0)
		_grid.position = Vector2((size.x - side) / 2.0, top)
		hint.position = Vector2(_grid.position.x, top - row_h - margin / 2.0)
		hint.size = Vector2(side, row_h)
		_icon_center = Vector2(
			_grid.position.x + row_h * ICON_RADIUS, hint.position.y + row_h / 2.0
		)
		var bottom: float = top + side + margin / 2.0
		_counter.position = Vector2(_grid.position.x, bottom)
		_counter.size = Vector2(side / 2.0, row_h)
		commit_button.position = Vector2(_grid.position.x + side - commit_w, bottom)
	_grid.size = Vector2(side, side)
	commit_button.size = Vector2(commit_w, row_h)
	queue_redraw()


## Clockwise rotation arrow next to the hint (SPEC: Rotated modifier).
func _draw() -> void:
	if slot == null or slot.modifier != GridGen.MOD_ROTATED or _grid == null:
		return
	var r: float = get_theme_constant("tap_min", "Hardwire") * ICON_RADIUS
	var c: Vector2 = _icon_center
	var color: Color = get_theme_color("ram", "Hardwire")
	var end: float = ARROW_START + ARROW_SWEEP
	draw_arc(c, r, ARROW_START, end, ARC_SEGMENTS, color, r * ARROW_WIDTH, true)
	var tip: Vector2 = c + Vector2.from_angle(end) * r
	var dir: Vector2 = Vector2.from_angle(end + PI / 2.0)
	var side: Vector2 = Vector2.from_angle(end) * r * ARROW_HEAD_HALF
	var head := PackedVector2Array([tip + dir * r * ARROW_HEAD_LENGTH, tip + side, tip - side])
	draw_colored_polygon(head, color)
