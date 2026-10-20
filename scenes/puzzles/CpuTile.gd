class_name CpuTile
extends Control
## The central CPU tile: a big square switch (DESIGN: Minigame surfaces) that goes in and glows in
## the CPU accent color while lit, scaling to glow_scale_pct over glow_ms. Input is handled by
## CpuPuzzle.

var lit: bool = false:
	set(value):
		if value == lit:
			return
		lit = value
		queue_redraw()
		_animate()

var _tween: Tween


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
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(get_theme_stylebox("pressed" if lit else "normal", "Button"), rect)
	var accent: Color = get_theme_color("cpu", "Hardwire")
	Ui.draw_glow(self, rect, Color(accent, 1.0 if lit else Ui.pct(self, "pad_idle_pct")))
	Ui.draw_focus(self, rect)
