class_name TimerBar
extends Control
## Horizontal bar showing remaining input time (fraction 0..1) in the given accent color.

var fraction: float = 1.0:
	set(value):
		if not is_equal_approx(value, fraction):
			fraction = value
			queue_redraw()
var color: Color = Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius: float = size.y / 2.0
	_draw_pill(Rect2(Vector2.ZERO, size), get_theme_color("trace", "Hardwire"), radius)
	if fraction > 0.0:
		_draw_pill(Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * fraction), size.y)), color, radius)


func _draw_pill(rect: Rect2, fill: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)
