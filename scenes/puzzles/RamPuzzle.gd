extends PuzzleBase
## RAM minigame: recreate the grid pattern. SPEC: Minigame: RAM.
## The pattern shows for show_ms, then the player toggles cells and presses Commit once the
## set count equals the cells needed. A wrong Commit or the timeout fails the attempt.

var _attempt: Dictionary = {}
var _grid: RamGrid
var _hint: Label
var _counter: Label
var _commit: Button
var _shown: bool = false


func _ready() -> void:
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	add_child(_hint)
	_grid = RamGrid.new()
	add_child(_grid)
	_counter = Label.new()
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	add_child(_counter)
	_commit = Button.new()
	_commit.text = "Commit"
	_commit.pressed.connect(commit)
	add_child(_commit)
	resized.connect(_layout)
	_layout()


func expected() -> Array[int]:
	return _attempt.get("expected", [] as Array[int])


func pattern() -> Array[int]:
	return _attempt.get("pattern", [] as Array[int])


func grid() -> RamGrid:
	return _grid


func can_commit() -> bool:
	return phase == Phase.INPUT and _grid.on_cells().size() == expected().size()


## Toggles one cell during the input phase (called from _input; public for tests).
func toggle_cell(i: int) -> void:
	if phase != Phase.INPUT or i < 0 or i >= _grid.n * _grid.n:
		return
	_grid.set_on(i, not _grid.is_on(i))
	Synth.play_click()
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


func _input(event: InputEvent) -> void:
	if phase != Phase.INPUT:
		return
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	var i: int = _grid.cell_at(touch.position)
	if i >= 0:
		get_viewport().set_input_as_handled()
		toggle_cell(i)


func _build_attempt() -> void:
	_attempt = GridGen.make(slot, attempt_seed)
	time_limit_s = _attempt.time_limit_s
	_shown = false
	_grid.setup(_attempt.n)
	match slot.modifier:
		GridGen.MOD_INVERTED:
			_hint.text = "Set the dark cells"
		GridGen.MOD_ROTATED:
			_hint.text = "Enter it rotated"
		_:
			_hint.text = ""
	queue_redraw()
	_update_counter()
	_layout()


func _watch_update(t: float) -> bool:
	if t < _attempt.show_ms / 1000.0:
		if not _shown:
			_shown = true
			_grid.show_only(pattern())
		return false
	_grid.show_only([] as Array[int])
	return true


func _on_phase_entered(_p_phase: Phase) -> void:
	_update_counter()


func _on_fail_reveal() -> void:
	_grid.show_only(expected())
	_update_counter()


func _on_abort() -> void:
	_update_counter()


func _update_counter() -> void:
	var input: bool = phase == Phase.INPUT
	_counter.visible = input
	_commit.visible = input or phase == Phase.RESULT
	_commit.disabled = not can_commit()
	_counter.text = "%d / %d" % [_grid.on_cells().size(), expected().size()]


## Hint row (and rotation icon) on top, square grid in the middle, counter and Commit below.
func _layout() -> void:
	if _grid == null:
		return
	var margin: float = get_theme_constant("margin", "Hardwire")
	var row_h: float = get_theme_constant("tap_min", "Hardwire")
	var side: float = maxf(0.0, minf(size.x - 2.0 * margin, size.y - 2.0 * row_h - 2.0 * margin))
	var top: float = maxf(row_h + margin, (size.y - side) / 2.0)
	_grid.position = Vector2((size.x - side) / 2.0, top)
	_grid.size = Vector2(side, side)
	_hint.position = Vector2(0.0, top - row_h - margin / 2.0)
	_hint.size = Vector2(size.x, row_h)
	var bottom: float = top + side + margin / 2.0
	_counter.position = Vector2(_grid.position.x, bottom)
	_counter.size = Vector2(side / 2.0, row_h)
	_commit.position = Vector2(_grid.position.x + side - row_h * 3.0, bottom)
	_commit.size = Vector2(row_h * 3.0, row_h)
	queue_redraw()


## Clockwise rotation arrow next to the hint (SPEC: Rotated modifier).
func _draw() -> void:
	if slot == null or slot.modifier != GridGen.MOD_ROTATED or _grid == null:
		return
	var r: float = get_theme_constant("tap_min", "Hardwire") * 0.3
	var c := Vector2(_grid.position.x + r, _hint.position.y + _hint.size.y / 2.0)
	var color: Color = get_theme_color("ram", "Hardwire")
	var start: float = -PI * 0.75
	var end: float = start + PI * 1.5
	draw_arc(c, r, start, end, 32, color, r * 0.28, true)
	var tip: Vector2 = c + Vector2.from_angle(end) * r
	var dir: Vector2 = Vector2.from_angle(end + PI / 2.0)
	var side: Vector2 = Vector2.from_angle(end) * r * 0.6
	draw_colored_polygon(PackedVector2Array([tip + dir * r * 0.8, tip + side, tip - side]), color)
