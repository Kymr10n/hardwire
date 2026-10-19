class_name RamGrid
extends Control
## Square grid of RAM cells drawn in one _draw. Each cell is on or off; on cells brighten
## and scale to glow_scale_pct over glow_ms (SPEC: Visual style). Input is handled by RamPuzzle.

var n: int = 0

var _on: Array[bool] = []
var _scale: Array[float] = []
var _style := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_n: int) -> void:
	n = p_n
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
		if _cell_rect(i).has_point(local):
			return i
	return -1


func _process(delta: float) -> void:
	var glow_s: float = maxf(0.001, get_theme_constant("glow_ms", "Hardwire") / 1000.0)
	var big: float = get_theme_constant("glow_scale_pct", "Hardwire") / 100.0
	var step: float = (big - 1.0) * delta / glow_s
	var changed: bool = false
	for i: int in _scale.size():
		var target: float = big if _on[i] else 1.0
		if not is_equal_approx(_scale[i], target):
			_scale[i] = move_toward(_scale[i], target, step)
			changed = true
	if changed:
		queue_redraw()


func _cell_rect(i: int) -> Rect2:
	var gap: float = size.x * 0.03
	var cell: float = (size.x - gap * (n - 1)) / n
	var row: int = floori(float(i) / n)
	var col: int = i % n
	return Rect2(Vector2(col, row) * (cell + gap), Vector2(cell, cell))


func _draw() -> void:
	var lit: Color = get_theme_color("ram", "Hardwire")
	var idle: Color = get_theme_color("trace", "Hardwire").darkened(0.4)
	for i: int in n * n:
		var rect: Rect2 = _cell_rect(i)
		rect = rect.grow((rect.size.x * _scale[i] - rect.size.x) / 2.0)
		_style.bg_color = lit if _on[i] else idle
		_style.set_corner_radius_all(int(rect.size.x * 0.14))
		draw_style_box(_style, rect)
