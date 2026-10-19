class_name StoragePad
extends Control
## One colored pad of the Storage ring: distinct color and symbol (colorblind-safe), lit level 0..1.
## Lit pads brighten and scale up (theme: glow_ms, glow_scale_pct). Input is handled by StoragePuzzle.

enum Symbol { CIRCLE, TRIANGLE, SQUARE, DIAMOND, STAR, PLUS, HEXAGON, RING }

var index: int = 0

var _level: float = 0.0
var _flash_left: float = 0.0
var _tween: Tween
var _style := StyleBoxFlat.new()


func _init(p_index: int = 0) -> void:
	index = p_index
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func level() -> float:
	return _level


## Sets the lit level (0 = idle, 1 = fully lit). Cancels a running tap flash.
func set_level(p_level: float) -> void:
	_flash_left = 0.0
	_apply_level(p_level)


## Short full-brightness flash for a tap.
func flash() -> void:
	_apply_level(1.0)
	_flash_left = get_theme_constant("tap_flash_ms", "Hardwire") / 1000.0


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash_left = 0.0
			_apply_level(0.0)


func _apply_level(p_level: float) -> void:
	if is_equal_approx(p_level, _level):
		return
	_level = p_level
	queue_redraw()
	if _tween:
		_tween.kill()
	var target: float = 1.0
	if p_level > 0.0:
		target = get_theme_constant("glow_scale_pct", "Hardwire") / 100.0
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * target, get_theme_constant("glow_ms", "Hardwire") / 1000.0)


func _draw() -> void:
	var base: Color = get_theme_color("pad_%d" % index, "Hardwire")
	var idle: Color = base.darkened(1.0 - get_theme_constant("pad_idle_pct", "Hardwire") / 100.0)
	_style.bg_color = idle.lerp(base.lightened(0.15), _level)
	_style.set_corner_radius_all(int(size.x * 0.18))
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var mark: Color = get_theme_color("bg", "Hardwire")
	if _level <= 0.0:
		mark = base.darkened(0.2)
	_draw_symbol(index % Symbol.size(), size / 2.0, size.x * 0.2, mark)
	Ui.draw_focus(self, Rect2(Vector2.ZERO, size))


func _draw_symbol(symbol: int, c: Vector2, r: float, color: Color) -> void:
	match symbol:
		Symbol.CIRCLE:
			draw_circle(c, r, color)
		Symbol.TRIANGLE:
			draw_colored_polygon(_regular(c, r * 1.15, 3, -PI / 2.0), color)
		Symbol.SQUARE:
			draw_rect(Rect2(c - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), color)
		Symbol.DIAMOND:
			draw_colored_polygon(_regular(c, r * 1.1, 4, -PI / 2.0), color)
		Symbol.STAR:
			var points := PackedVector2Array()
			for i: int in 10:
				var radius: float = r * 1.15 if i % 2 == 0 else r * 0.5
				points.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * radius)
			draw_colored_polygon(points, color)
		Symbol.PLUS:
			draw_rect(Rect2(c - Vector2(r, r * 0.3), Vector2(r * 2.0, r * 0.6)), color)
			draw_rect(Rect2(c - Vector2(r * 0.3, r), Vector2(r * 0.6, r * 2.0)), color)
		Symbol.HEXAGON:
			draw_colored_polygon(_regular(c, r, 6, 0.0), color)
		Symbol.RING:
			draw_arc(c, r * 0.8, 0.0, TAU, 32, color, r * 0.4, true)


static func _regular(c: Vector2, r: float, sides: int, start: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in sides:
		points.append(c + Vector2.from_angle(start + i * TAU / sides) * r)
	return points
