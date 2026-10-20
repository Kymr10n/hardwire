class_name CpuMarkers
extends Control
## Beat markers under the CPU tile (SPEC: Watch phase, D-022), an LED strip (DESIGN: Minigame
## surfaces): a round LED per tap and a bar LED as long as its steps per hold; the first
## `filled` of them are lit and the `missed` one (the beat that broke the attempt, D-030) is red.
## Under Audio only (`plain`) every marker is a dot, so lengths must be heard.

## Radius as a fraction of tap_min; gap and outline as fractions of the radius.
const RADIUS := 0.2
const GAP := 1.0
const RING := 0.3

var steps: Array[float] = []  # on, off, on, ... in steps (a RhythmGen attempt's `steps`)
var plain: bool = false
var filled: int = 0:
	set(value):
		filled = value
		queue_redraw()
var missed: int = -1:
	set(value):
		missed = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_steps: Array[float], p_plain: bool) -> void:
	steps = p_steps
	plain = p_plain
	filled = 0
	missed = -1


## Markers laid out centered in this control's width, inside the theme margins, 2 r tall.
## Widths in radii: 2 per step for holds, 2 for taps (and for every beat when plain). The radius
## shrinks only if the row would not fit.
func rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if steps.is_empty():
		return out
	var units: Array[float] = []
	var total: float = GAP * (floori((steps.size() + 1) / 2.0) - 1)
	for i: int in range(0, steps.size(), 2):
		var u: float = 2.0 * (1.0 if plain else maxf(1.0, steps[i]))
		units.append(u)
		total += u
	var margin: float = get_theme_constant("margin", "Hardwire")
	var tap: float = get_theme_constant("tap_min", "Hardwire")
	var r: float = minf(tap * RADIUS, (size.x - 2.0 * margin) / total)
	var x: float = (size.x - total * r) / 2.0
	for u: float in units:
		out.append(Rect2(x, 0.0, u * r, r * 2.0))
		x += (u + GAP) * r
	return out


func _draw() -> void:
	var all: Array[Rect2] = rects()
	if all.is_empty():
		return
	var ring: float = all[0].size.y / 2.0 * RING
	var off: Color = get_theme_color("card_locked", "Hardwire")
	var on: Color = get_theme_color("cpu", "Hardwire")
	for i: int in all.size():
		var color: Color = on if i < filled else off
		if i == missed:
			color = get_theme_color("fail", "Hardwire")
		_draw_led(all[i], ring, color)


## A dark ring with the LED inside: round when square (a tap), a bar otherwise (a hold).
func _draw_led(rect: Rect2, ring: float, color: Color) -> void:
	var dark: Color = get_theme_color("text_dim", "Hardwire")
	if is_equal_approx(rect.size.x, rect.size.y):
		var r: float = rect.size.y / 2.0
		draw_circle(rect.get_center(), r, dark)
		draw_circle(rect.get_center(), r - ring, color)
	else:
		draw_rect(rect, dark)
		draw_rect(rect.grow(-ring), color)
