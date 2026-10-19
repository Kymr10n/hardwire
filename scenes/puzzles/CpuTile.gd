class_name CpuTile
extends Control
## The central CPU tile: a large rounded square that lights in the CPU accent color.
## Lit state brightens and scales to glow_scale_pct over glow_ms. Input is handled by CpuPuzzle.

var lit: bool = false:
	set(value):
		if value == lit:
			return
		lit = value
		queue_redraw()
		_animate()

var _tween: Tween
var _style := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func _animate() -> void:
	if not is_inside_tree():
		return
	if _tween:
		_tween.kill()
	var target: float = get_theme_constant("glow_scale_pct", "Hardwire") / 100.0 if lit else 1.0
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * target, get_theme_constant("glow_ms", "Hardwire") / 1000.0)


func _draw() -> void:
	var accent: Color = get_theme_color("cpu", "Hardwire")
	_style.bg_color = accent if lit else accent.darkened(1.0 - get_theme_constant("pad_idle_pct", "Hardwire") / 100.0)
	_style.set_corner_radius_all(int(size.x * 0.12))
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	Ui.draw_focus(self, Rect2(Vector2.ZERO, size))
