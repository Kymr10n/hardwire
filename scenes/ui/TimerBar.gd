class_name TimerBar
extends ProgressBar
## Pill-shaped bar showing remaining input time (value 0..1) in the given accent color.

var color: Color = Color.WHITE:
	set(value):
		color = value
		_fill.bg_color = value

var _fill := StyleBoxFlat.new()
var _background := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_percentage = false
	max_value = 1.0
	step = 0.0
	add_theme_stylebox_override("background", _background)
	add_theme_stylebox_override("fill", _fill)
	resized.connect(_round_corners)


func _ready() -> void:
	_background.bg_color = get_theme_color("trace", "Hardwire")


func _round_corners() -> void:
	for style: StyleBoxFlat in [_background, _fill]:
		style.set_corner_radius_all(int(size.y / 2.0))
