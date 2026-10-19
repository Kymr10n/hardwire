extends Control
## Root scene. Holds the current screen and handles transitions (SPEC: Screens and UX flow).
## M1: shows the stats and, in debug builds, a button that adds stats and saves.
## Replaced by Boot/Overview in M5.

var _stats_label: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0d1117")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 48)
	add_child(box)

	var title := _make_label("HARDWIRE", 72)
	box.add_child(title)

	_stats_label = _make_label("", 48)
	box.add_child(_stats_label)

	if OS.is_debug_build():
		var button := Button.new()
		button.text = "DEBUG: +%d all stats" % Balance.get_int("debug", "stat_step")
		button.custom_minimum_size = Vector2(600, 140)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 40)
		button.pressed.connect(_on_debug_add_pressed)
		box.add_child(button)

	GameState.stats_changed.connect(_refresh)
	GameState.cycles_changed.connect(_refresh)
	_refresh()


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("5ee6ff"))
	return label


func _refresh() -> void:
	_stats_label.text = "RAM %d\nCPU %d\nSTO %d\nCycles %d" % [GameState.ram, GameState.cpu, GameState.sto, GameState.cycles]


func _on_debug_add_pressed() -> void:
	var step: int = Balance.get_int("debug", "stat_step")
	GameState.add_stats(step, step, step)
	SaveManager.save_game()
