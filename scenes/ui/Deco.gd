class_name Deco
extends Control
## Decorations drawn in code (DESIGN: Authenticity kit): a row of vent slits used as a section
## separator, or a bank of LEDs of which the first `lit` are on.

enum Kind { VENT, LED_BANK }

## LED gap as a fraction of led_size; vent slit length and gap as fractions of tap_min.
const LED_GAP := 0.25
const SLIT_LENGTH := 0.2
const SLIT_GAP := 0.1
const VENT_ROWS := 3

var kind: Kind = Kind.VENT
var count: int = 0
var lit: int = 0:
	set(value):
		lit = value
		queue_redraw()
var color: Color = Color.WHITE


func _init(p_kind: Kind = Kind.VENT) -> void:
	kind = p_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A vent row that spans its container; VENT_ROWS slits tall.
static func vent() -> Deco:
	var d := Deco.new(Kind.VENT)
	var slit: int = ThemeDB.get_project_theme().get_constant("vent_slit_h", "Hardwire")
	d.custom_minimum_size.y = slit * 2 * VENT_ROWS
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d


## A bank of `count` LEDs lit in `p_color`.
static func leds(p_color: Color, p_count: int) -> Deco:
	var d := Deco.new(Kind.LED_BANK)
	d.color = p_color
	d.count = p_count
	var led: float = ThemeDB.get_project_theme().get_constant("led_size", "Hardwire")
	d.custom_minimum_size = Vector2(led * (p_count + LED_GAP * (p_count - 1)), led)
	return d


func _draw() -> void:
	if kind == Kind.VENT:
		_draw_vent()
	else:
		_draw_leds()


func _draw_vent() -> void:
	var h: float = get_theme_constant("vent_slit_h", "Hardwire")
	var tap: float = get_theme_constant("tap_min", "Hardwire")
	var length: float = tap * SLIT_LENGTH
	var pitch: float = length + tap * SLIT_GAP
	var dark: Color = get_theme_color("metal_dark", "Hardwire")
	for row: int in VENT_ROWS:
		var x: float = 0.0
		while x + length <= size.x:
			draw_rect(Rect2(x, row * 2 * h, length, h), dark)
			x += pitch


func _draw_leds() -> void:
	var led: float = get_theme_constant("led_size", "Hardwire")
	var r: float = led / 2.0
	var ring: Color = get_theme_color("text_dim", "Hardwire")
	var off: Color = get_theme_color("card_locked", "Hardwire")
	for i: int in count:
		var center := Vector2(r + i * led * (1.0 + LED_GAP), size.y / 2.0)
		draw_circle(center, r, ring)
		draw_circle(center, r - 1, color if i < lit else off)
