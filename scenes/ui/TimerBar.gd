class_name TimerBar
extends ProgressBar
## Recessed bar showing remaining input time (value 0..1) as a glowing fill in the accent color.

var color: Color = Color.WHITE:
	set(value):
		color = value
		_fill.bg_color = value

var _fill := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_percentage = false
	max_value = 1.0
	step = 0.0
	add_theme_stylebox_override("fill", _fill)


func _ready() -> void:
	add_theme_stylebox_override("background", get_theme_stylebox("recess", "Hardwire"))
