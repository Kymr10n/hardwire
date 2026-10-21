class_name CpuTile
extends Control
## The central CPU tile: a large square that lights in the CPU accent color.
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
	Ui.make_focusable(self)


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func _animate() -> void:
	if not is_inside_tree():
		return
	if _tween:
		_tween.kill()
	var target: float = Ui.pct(self, "glow_scale_pct") if lit else 1.0
	_tween = create_tween()
	_tween.tween_property(
		self, "scale", Vector2.ONE * target, get_theme_constant("glow_ms", "Hardwire") / 1000.0
	)


func _draw() -> void:
	var accent: Color = get_theme_color("cpu", "Hardwire")
	_style.bg_color = (accent if lit else accent.darkened(1.0 - Ui.pct(self, "pad_idle_pct")))
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	Ui.draw_focus(self, Rect2(Vector2.ZERO, size))
