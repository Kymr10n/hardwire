class_name Bezel
extends Control
## Instrument frame around the puzzle area (D-041): a trace outline at the edge with corner
## ticks. pulse() flashes the frame in a colour (accent on success, fail on failure) that fades
## back over pulse_ms. The puzzle is anchored inside it by inset(); input passes through.

## Puzzle inset and corner tick length as fractions of the theme margin.
const INSET := 0.25
const TICK := 0.25

## The frame colour: trace at rest, the pulse colour while it fades back.
var color: Color:
	set(p_color):
		color = p_color
		queue_redraw()

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = get_theme_color("trace", "Hardwire")


## Space between the frame and the puzzle inside it.
func inset() -> int:
	return int(get_theme_constant("margin", "Hardwire") * INSET)


func pulse(p_color: Color) -> void:
	if _tween:
		_tween.kill()
	color = p_color
	_tween = create_tween()
	_tween.tween_property(
		self,
		"color",
		get_theme_color("trace", "Hardwire"),
		get_theme_constant("pulse_ms", "Hardwire") / 1000.0
	)


func _draw() -> void:
	var outline: int = get_theme_constant("outline_width", "Hardwire")
	draw_rect(Rect2(Vector2.ZERO, size), color, false, outline)
	var tick: float = get_theme_constant("margin", "Hardwire") * TICK
	var thick: float = outline
	var dim: Color = get_theme_color("text_dim", "Hardwire")
	for corner: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
		var c: Vector2 = size * corner
		var dir := Vector2(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
		draw_line(c, c + Vector2(dir.x * tick, 0), dim, thick)
		draw_line(c, c + Vector2(0, dir.y * tick), dim, thick)
