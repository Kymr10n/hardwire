class_name RamGrid
extends Control
## Square grid of RAM cells drawn in one _draw. Each cell is on or off; on cells brighten
## and scale to glow_scale_pct over glow_ms (SPEC: Visual style). Touch is handled by RamPuzzle.
## With focus, ui_* directions move a cursor and ui_accept emits cell_activated; at an edge the
## direction is left unhandled, so focus moves on to the next control (e.g. Commit).

signal cell_activated(index: int)

const DIRECTIONS := {
	"ui_left": Vector2i(-1, 0),
	"ui_right": Vector2i(1, 0),
	"ui_up": Vector2i(0, -1),
	"ui_down": Vector2i(0, 1)
}

## Cell look, as fractions of the grid / cell size.
const GAP := 0.03
const CORNER := 0.14
const IDLE_DARKEN := 0.4
const MIN_GLOW_S := 0.001

var n: int = 0
var cursor: int = 0

var _on: Array[bool] = []
var _scale: Array[float] = []
var _style := StyleBoxFlat.new()


func _init() -> void:
	Ui.make_focusable(self)


func setup(p_n: int) -> void:
	n = p_n
	cursor = 0
	_on.resize(n * n)
	_on.fill(false)
	_scale.resize(n * n)
	_scale.fill(1.0)
	queue_redraw()


func is_on(i: int) -> bool:
	return _on[i]


func set_on(i: int, value: bool) -> void:
	if _on[i] != value:
		_on[i] = value
		queue_redraw()


## Turns exactly the given cells on and all others off.
func show_only(cells: Array[int]) -> void:
	for i: int in _on.size():
		set_on(i, cells.has(i))


func on_cells() -> Array[int]:
	var out: Array[int] = []
	for i: int in _on.size():
		if _on[i]:
			out.append(i)
	return out


## Cell under a global (canvas) position, or -1 (including the gaps between cells).
func cell_at(global_pos: Vector2) -> int:
	if n == 0:
		return -1
	var local: Vector2 = global_pos - global_position
	for i: int in n * n:
		if cell_rect(i).has_point(local):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if Ui.accept_event(event) == 1:
		accept_event()
		_show_focus()
		cell_activated.emit(cursor)
		return
	for action: String in DIRECTIONS:
		if event.is_action_pressed(action, true):
			var cell: Vector2i = (
				Vector2i(cursor % n, floori(float(cursor) / n)) + DIRECTIONS[action]
			)
			if cell.x >= 0 and cell.x < n and cell.y >= 0 and cell.y < n:
				cursor = cell.y * n + cell.x
				accept_event()
				_show_focus()
			return


## The grid handles its own directions, so Godot never un-hides focus that was grabbed hidden;
## do it on the first gamepad/keyboard use.
func _show_focus() -> void:
	if not has_focus(true):
		grab_focus()
	queue_redraw()


func _process(delta: float) -> void:
	var glow_s: float = maxf(MIN_GLOW_S, get_theme_constant("glow_ms", "Hardwire") / 1000.0)
	var big: float = Ui.pct(self, "glow_scale_pct")
	var step: float = (big - 1.0) * delta / glow_s
	var changed: bool = false
	for i: int in _scale.size():
		var target: float = big if _on[i] else 1.0
		if not is_equal_approx(_scale[i], target):
			_scale[i] = move_toward(_scale[i], target, step)
			changed = true
	if changed:
		queue_redraw()


func cell_rect(i: int) -> Rect2:
	var gap: float = size.x * GAP
	var cell: float = (size.x - gap * (n - 1)) / n
	var row: int = floori(float(i) / n)
	var col: int = i % n
	return Rect2(Vector2(col, row) * (cell + gap), Vector2(cell, cell))


func _draw() -> void:
	var lit: Color = get_theme_color("ram", "Hardwire")
	var idle: Color = get_theme_color("trace", "Hardwire").darkened(IDLE_DARKEN)
	for i: int in n * n:
		var rect: Rect2 = cell_rect(i)
		rect = rect.grow((rect.size.x * _scale[i] - rect.size.x) / 2.0)
		_style.bg_color = lit if _on[i] else idle
		_style.set_corner_radius_all(int(rect.size.x * CORNER))
		draw_style_box(_style, rect)
	if n > 0:
		Ui.draw_focus(self, cell_rect(cursor))
