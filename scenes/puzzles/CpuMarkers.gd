class_name CpuMarkers
extends Control
## Beat markers under the CPU tile (SPEC: Watch phase, D-022): a square tick per tap and a bar as
## long as its steps per hold; the first `filled` of them are lit and the `missed` one (the beat
## that broke the attempt, D-030) is red. Under Audio only (`plain`) every marker is a tick, so
## lengths must be heard.

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

var _on := StyleBoxFlat.new()
var _off := StyleBoxFlat.new()
var _miss := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_off.draw_center = false


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
	var r: float = all[0].size.y / 2.0
	_on.bg_color = get_theme_color("cpu", "Hardwire")
	_miss.bg_color = get_theme_color("fail", "Hardwire")
	_off.border_color = get_theme_color("text_dim", "Hardwire")
	_off.set_border_width_all(int(r * RING))
	for i: int in all.size():
		var style: StyleBoxFlat = _on if i < filled else _off
		draw_style_box(_miss if i == missed else style, all[i])
