class_name StatBar
extends BoxContainer
## Stats: RAM, CPU, STO in their accent colors, then Cycles and Cores. Updates on GameState signals.
## A row in portrait; set `vertical` for the landscape sidebar. In debug builds, tapping it
## debug.panel_taps times within debug.panel_tap_window_s opens the debug panel.

signal debug_requested

var _labels := {}
var _taps: Array[float] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire") / 2)
	custom_minimum_size.y = get_theme_constant("tap_min", "Hardwire")
	for key: String in SlotGenerator.TYPES + ["cycles", "cores"]:
		var label := Label.new()
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", get_theme_font_size("body", "Hardwire"))
		if key in SlotGenerator.TYPES:
			label.add_theme_color_override("font_color", get_theme_color(key, "Hardwire"))
		elif key == "cores":
			label.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
		add_child(label)
		_labels[key] = label
	GameState.stats_changed.connect(refresh)
	GameState.cycles_changed.connect(refresh)
	GameState.cores_changed.connect(refresh)
	refresh()


func refresh() -> void:
	_labels.ram.text = "RAM " + short(GameState.ram)
	_labels.cpu.text = "CPU " + short(GameState.cpu)
	_labels.sto.text = "STO " + short(GameState.sto)
	_labels.cycles.text = "Cyc " + short(GameState.cycles)
	_labels.cores.text = "Cores " + short(GameState.cores)


## Compact number so the bar fits a phone width: 9999, 12.3K, 4.56M.
static func short(n: int) -> String:
	if n < 10_000:
		return str(n)
	if n < 1_000_000:
		return "%.1fK" % (n / 1000.0)
	return "%.2fM" % (n / 1_000_000.0)


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed or not OS.is_debug_build():
		return
	if not get_global_rect().has_point(touch.position):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var window: float = Balance.get_num("debug", "panel_tap_window_s")
	_taps.append(now)
	_taps = _taps.filter(func(t: float) -> bool: return now - t <= window)
	if _taps.size() >= Balance.get_int("debug", "panel_taps"):
		_taps.clear()
		debug_requested.emit()
