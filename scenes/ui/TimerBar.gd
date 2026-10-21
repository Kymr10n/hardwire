class_name TimerBar
extends Control
## Segmented bar of remaining input time (value 0..1): timer_segments blocks in the given accent,
## spent blocks dark with a trace outline (D-041).

var color: Color = Color.WHITE:
	set(p_color):
		color = p_color
		queue_redraw()
var value: float = 1.0:
	set(p_value):
		var lit: int = lit_segments()
		value = p_value
		if lit_segments() != lit:
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Blocks still lit: the last one stays until the time is fully up.
func lit_segments() -> int:
	return ceili(clampf(value, 0.0, 1.0) * get_theme_constant("timer_segments", "Hardwire"))


func _draw() -> void:
	var n: int = get_theme_constant("timer_segments", "Hardwire")
	var gap: int = get_theme_constant("outline_width", "Hardwire")
	var width: float = (size.x - gap * (n - 1)) / n
	var lit: int = lit_segments()
	var dark: Color = get_theme_color("card", "Hardwire")
	var trace: Color = get_theme_color("trace", "Hardwire")
	for i: int in n:
		var rect := Rect2(i * (width + gap), 0.0, width, size.y)
		if i < lit:
			draw_rect(rect, color)
		else:
			draw_rect(rect, dark)
			draw_rect(rect, trace, false, gap)
