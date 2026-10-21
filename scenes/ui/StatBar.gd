class_name StatBar
extends BoxContainer
## Readout: RAM, CPU, STO in their hues, then Cycles and Cores, each behind a square lamp. When a
## value changes it counts up over flow.reward_countup_s while its lamp flashes (D-041). Updates on
## GameState signals. A row in portrait; set `vertical` for the landscape sidebar. In debug builds,
## tapping it debug.panel_taps times within debug.panel_tap_window_s opens the debug panel.

signal debug_requested

const NAMES := {"cycles": "Cyc", "cores": "Cores"}

var _values := {}
var _lamps := {}
var _shown := {}
var _taps: Array[float] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire") / 2)
	custom_minimum_size.y = get_theme_constant("tap_min", "Hardwire")
	for key: String in SlotGenerator.TYPES + ["cycles", "cores"]:
		add_child(_entry(key))
	GameState.stats_changed.connect(refresh)
	GameState.cycles_changed.connect(refresh)
	GameState.cores_changed.connect(refresh)
	refresh()


## The stat hue for RAM, CPU and STO; Cycles in text, Cores dim.
func _entry_color(key: String) -> Color:
	var hue: String = key if key in SlotGenerator.TYPES else "text"
	return get_theme_color("text_dim" if key == "cores" else hue, "Hardwire")


## Lamp, dim name and value, all in the entry's colour.
func _entry(key: String) -> HBoxContainer:
	var color: Color = _entry_color(key)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", get_theme_constant("tag_pad", "Hardwire"))
	var lamp := ColorRect.new()
	lamp.color = color
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lamp.custom_minimum_size = Vector2.ONE * get_theme_constant("lamp_size", "Hardwire")
	lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lamp)
	var label: Label = Ui.dim_label(NAMES.get(key, SlotDef.STAT_NAMES.get(key, key)))
	label.uppercase = true
	label.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
	row.add_child(label)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
	value.add_theme_color_override("font_color", color)
	row.add_child(value)
	_lamps[key] = lamp
	_values[key] = value
	# Seeded with the live value: only a change counts up, not opening the screen.
	_show(_current()[key], key)
	return row


static func _current() -> Dictionary:
	return {
		"ram": GameState.ram,
		"cpu": GameState.cpu,
		"sto": GameState.sto,
		"cycles": GameState.cycles,
		"cores": GameState.cores,
	}


## A rise counts up with a lamp flash; a drop (a Rebuild) shows at once.
func refresh() -> void:
	var now: Dictionary = _current()
	for key: String in now:
		if now[key] == _shown[key]:
			continue
		if now[key] < _shown[key]:
			_show(now[key], key)
			continue
		# The lamp flashes accent and fades back while the value counts up.
		var lamp: ColorRect = _lamps[key]
		lamp.color = get_theme_color("accent", "Hardwire")
		create_tween().tween_property(lamp, "color", _entry_color(key), _countup_s())
		create_tween().tween_method(_show.bind(key), _shown[key], now[key], _countup_s())


func value_text(key: String) -> String:
	return _values[key].text


func _show(n: int, key: String) -> void:
	_shown[key] = n
	_values[key].text = short(n)


static func _countup_s() -> float:
	return Balance.get_num("flow", "reward_countup_s")


## Compact number so the bar fits a phone width: 9999, 12.3K, 4.56M.
static func short(n: int) -> String:
	if n < 10_000:
		return str(n)
	if n < 1_000_000:
		return "%.1fK" % (n / 1000.0)
	return "%.2fM" % (n / 1_000_000.0)


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed or not OS.is_debug_build():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var window: float = Balance.get_num("debug", "panel_tap_window_s")
	_taps.append(now)
	_taps = _taps.filter(func(t: float) -> bool: return now - t <= window)
	if _taps.size() >= Balance.get_int("debug", "panel_taps"):
		_taps.clear()
		debug_requested.emit()
