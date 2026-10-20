class_name StatBar
extends PanelContainer
## The front panel (DESIGN: Stat bar): per stat a label, a readout and a bank of LEDs lit by the
## progress to the next tier; then the Cycles readout, which pulses when it changes, and Cores.
## Updates on GameState signals. A row in portrait; set `vertical` for the landscape sidebar. In
## debug builds, tapping it debug.panel_taps times within debug.panel_tap_window_s opens the
## debug panel.

signal debug_requested

const LEDS := 10
## Silkscreen captions that differ from the key.
const CAPTIONS := {"cycles": "CYC"}

var vertical: bool = false

var _readouts: Dictionary[String, Label] = {}
var _banks: Dictionary[String, Deco] = {}
var _cycles: int = -1
var _taps: Array[float] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", get_theme_stylebox("bay", "Hardwire"))
	var box: BoxContainer = Ui.box(vertical)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	for key: String in SlotGenerator.TYPES:
		var meter: VBoxContainer = _meter(box, key, "text")
		_banks[key] = Deco.leds(get_theme_color("led_green", "Hardwire"), LEDS)
		meter.add_child(_banks[key])
	var wallet: VBoxContainer = _meter(box, "cycles", "led_amber")
	_row(wallet, "cores", "text_dim")
	GameState.stats_changed.connect(refresh)
	GameState.cycles_changed.connect(refresh)
	GameState.cores_changed.connect(refresh)
	refresh()


## A meter column holding a label + readout row for `key`.
func _meter(parent: Control, key: String, color: String) -> VBoxContainer:
	var meter := VBoxContainer.new()
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(meter)
	_row(meter, key, color)
	return meter


## "KEY ..... value": a silkscreen label and a dot-matrix readout in the theme color `color`.
func _row(parent: Control, key: String, color: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = CAPTIONS.get(key, key)
	label.uppercase = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
	row.add_child(label)
	var readout: Label = Ui.readout("", color)
	# Smaller than the shop readouts so four meters fit a phone width.
	readout.add_theme_font_size_override(
		"font_size", get_theme_font_size("readout_small", "Hardwire")
	)
	row.add_child(readout)
	_readouts[key] = readout


func refresh() -> void:
	var stats: Dictionary = GameState.stats()
	var tier: int = Progress.highest_unlocked_tier(stats)
	for key: String in SlotGenerator.TYPES:
		var value: int = stats[key]
		_readouts[key].text = short(value)
		_banks[key].lit = Progress.tier_leds(value, tier, LEDS)
	_readouts.cycles.text = short(GameState.cycles)
	_readouts.cores.text = short(GameState.cores)
	if _cycles >= 0 and _cycles != GameState.cycles:
		pulse()
	_cycles = GameState.cycles


## The Cycles readout flashes bright once (the HDD light of the UI).
func pulse() -> void:
	var readout: Label = _readouts.cycles
	readout.add_theme_color_override("font_color", get_theme_color("plastic_light", "Hardwire"))
	create_tween().tween_property(
		readout,
		"theme_override_colors/font_color",
		get_theme_color("led_amber", "Hardwire"),
		get_theme_constant("tap_flash_ms", "Hardwire") / 1000.0
	)


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
