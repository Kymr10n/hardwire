class_name StoragePad
extends Control
## One pad of the Storage ring: an LED under frosted plastic (DESIGN: Pads) with a distinct tint
## and symbol (colorblind-safe), lit level 0..1 as the glow inside its recess. Lit pads brighten
## and scale up with a small overshoot (theme: glow_ms, glow_scale_pct); a held pad goes in by
## the bevel like a keycap; a flickering pad (the decoy) blinks every glow_ms like a bad solder
## joint. A touch on the pad or the
## accept action while it has focus emits `tapped`; letting go emits `released` (with the pad's
## index for a touch, -1 for accept, whose release may come after focus moved). StoragePuzzle
## decides what they mean.

signal tapped(index: int)
signal released(index: int)

enum Symbol { CIRCLE, TRIANGLE, SQUARE, DIAMOND, STAR, PLUS, HEXAGON, RING }

## Pad look, as fractions of the pad size.
const SYMBOL_RADIUS := 0.2
## Regular polygons: [sides, radius scale, start angle].
const UP := -PI / 2.0
const POLYGONS := {
	Symbol.TRIANGLE: [3, 1.15, UP],
	Symbol.DIAMOND: [4, 1.1, UP],
	Symbol.HEXAGON: [6, 1.0, 0.0],
}
## Other symbols, as fractions of the symbol radius.
const SQUARE_HALF := 0.85
const STAR_POINTS := 5
const STAR_OUTER := 1.15
const STAR_INNER := 0.5
const PLUS_HALF_WIDTH := 0.3
const RING_RADIUS := 0.8
const RING_WIDTH := 0.4
const ARC_SEGMENTS := 32

var index: int = 0

var _level: float = 0.0
var _held: bool = false
var _dim: bool = false
var _min_light: Tween
var _tween: Tween
var _flicker: Tween


func _init(p_index: int = 0) -> void:
	index = p_index
	Ui.make_focusable(self)


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size / 2.0)


## The lit level as shown: 0 while a flicker has the LED off.
func level() -> float:
	return 0.0 if _dim else _level


## Sets the lit level (0 = idle, 1 = fully lit). Cancels a hold, its minimum flash and a flicker.
func set_level(p_level: float) -> void:
	_held = false
	_cancel_min_light()
	if _flicker:
		_flicker.kill()
		_flicker = null
	_dim = false
	_apply_level(p_level)


## Lit at `p_level`, blinking off every glow_ms until the next set_level().
func flicker(p_level: float) -> void:
	set_level(p_level)
	_flicker = create_tween().set_loops()
	_flicker.tween_callback(_toggle_flicker).set_delay(
		get_theme_constant("glow_ms", "Hardwire") / 1000.0
	)


func _toggle_flicker() -> void:
	_dim = not _dim
	queue_redraw()


## Fully lit until let_go(), and at least tap_flash_ms so a quick tap still shows.
func hold() -> void:
	set_level(1.0)
	_held = true
	queue_redraw()
	_min_light = create_tween()
	_min_light.tween_interval(get_theme_constant("tap_flash_ms", "Hardwire") / 1000.0)
	_min_light.tween_callback(_end_min_light)


func let_go() -> void:
	_held = false
	queue_redraw()
	if _min_light == null:
		_apply_level(0.0)


func _end_min_light() -> void:
	_min_light = null
	if not _held:
		_apply_level(0.0)


func _cancel_min_light() -> void:
	if _min_light:
		_min_light.kill()
		_min_light = null


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var accept: int = Ui.accept_event(event)
	if (touch != null and touch.pressed) or accept == 1:
		accept_event()
		tapped.emit(index)
	elif touch != null:
		accept_event()
		released.emit(index)
	elif accept == -1:
		accept_event()
		released.emit(-1)


func _apply_level(p_level: float) -> void:
	if is_equal_approx(p_level, _level):
		return
	_level = p_level
	queue_redraw()
	if _tween:
		_tween.kill()
	var target: float = 1.0
	if p_level > 0.0:
		target = Ui.pct(self, "glow_scale_pct")
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(
		self, "scale", Vector2.ONE * target, get_theme_constant("glow_ms", "Hardwire") / 1000.0
	)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(get_theme_stylebox("recess", "Hardwire"), rect)
	# The key goes in while held: its face shifts by the bevel.
	var face: Rect2 = rect
	if _held:
		face.position += Vector2.ONE * get_theme_constant("bevel", "Hardwire")
	var tint: Color = get_theme_color("pad_%d" % index, "Hardwire")
	var alpha: float = lerpf(Ui.pct(self, "pad_idle_pct"), 1.0, level())
	Ui.draw_glow(self, face, Color(tint, alpha))
	var mark: Color = get_theme_color("bg" if level() > 0.0 else "text", "Hardwire")
	_draw_symbol(index % Symbol.size(), face.get_center(), size.x * SYMBOL_RADIUS, mark)
	Ui.draw_focus(self, rect)


func _draw_symbol(symbol: int, c: Vector2, r: float, color: Color) -> void:
	if POLYGONS.has(symbol):
		var p: Array = POLYGONS[symbol]
		draw_colored_polygon(_regular(c, r * p[1], p[0], p[2]), color)
		return
	match symbol:
		Symbol.CIRCLE:
			draw_circle(c, r, color)
		Symbol.SQUARE:
			draw_rect(
				Rect2(c - Vector2.ONE * r * SQUARE_HALF, Vector2.ONE * r * SQUARE_HALF * 2), color
			)
		Symbol.STAR:
			var points := PackedVector2Array()
			for i: int in STAR_POINTS * 2:
				var radius: float = r * (STAR_OUTER if i % 2 == 0 else STAR_INNER)
				points.append(c + Vector2.from_angle(UP + i * PI / STAR_POINTS) * radius)
			draw_colored_polygon(points, color)
		Symbol.PLUS:
			var half: float = r * PLUS_HALF_WIDTH
			draw_rect(Rect2(c - Vector2(r, half), Vector2(r, half) * 2), color)
			draw_rect(Rect2(c - Vector2(half, r), Vector2(half, r) * 2), color)
		Symbol.RING:
			draw_arc(c, r * RING_RADIUS, 0.0, TAU, ARC_SEGMENTS, color, r * RING_WIDTH, true)


static func _regular(c: Vector2, r: float, sides: int, start: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in sides:
		points.append(c + Vector2.from_angle(start + i * TAU / sides) * r)
	return points
