extends Control
## Debug panel (debug builds only; SPEC: Technical architecture > debug panel), opened by tapping
## the stat bar. Sets stats, Cycles and tier, forces a minigame with an optional modifier and
## changes the time scale. All amounts come from balance.json "debug".

signal play_requested(slot: SlotDef)
signal exit_requested

const QUICK_TIERS: Array[int] = [1, 5, 10, 20]
const TYPES: Array[String] = [SlotDef.TYPE_STO, SlotDef.TYPE_RAM, SlotDef.TYPE_CPU]

## Kept across screen changes so returning from a puzzle keeps the picks.
static var tier: int = 1
static var type_index: int = 0
static var modifier_index: int = 0

var _stats_label: Label
var _tier_label: Label
var _type_button: Button
var _modifier_button: Button
var _play_button: Button
var _scale_button: Button


func _ready() -> void:
	var margin: int = get_theme_constant("margin", "Hardwire")
	var column: VBoxContainer = Ui.screen_root(self, get_theme_constant("max_column", "Hardwire"))
	var title: Label = Ui.header(column, "DEBUG", exit_requested.emit)
	title.add_theme_color_override("font_color", get_theme_color("fail", "Hardwire"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", margin / 2)
	scroll.add_child(box)

	_stats_label = _label("", 0)
	box.add_child(_stats_label)

	var stat_row := _row(box)
	for step: Variant in Balance.section("debug").get("stat_steps", []):
		stat_row.add_child(_button("+%d stats" % int(step), _add_stats.bind(int(step))))
	stat_row.add_child(_button("+%d Cyc" % Balance.get_int("debug", "cycles_step"), _add_cycles))

	box.add_child(_label("Tier", 0))
	var tier_row := _row(box)
	tier_row.add_child(_button("-", _change_tier.bind(-1)))
	_tier_label = _label("", get_theme_font_size("header", "Hardwire"))
	_tier_label.custom_minimum_size.x = get_theme_constant("tap_min", "Hardwire") * 2
	tier_row.add_child(_tier_label)
	tier_row.add_child(_button("+", _change_tier.bind(1)))
	var quick_row := _row(box)
	for t: int in QUICK_TIERS:
		quick_row.add_child(_button("T%d" % t, _set_tier.bind(t)))
	box.add_child(_button("Set stats to tier requirement", _set_stats_for_tier))

	_type_button = _button("", _cycle_type)
	box.add_child(_type_button)
	_modifier_button = _button("", _cycle_modifier)
	box.add_child(_modifier_button)
	_play_button = _button("Play", _on_play)
	box.add_child(_play_button)
	_scale_button = _button("", _cycle_time_scale)
	box.add_child(_scale_button)

	GameState.stats_changed.connect(_refresh)
	GameState.cycles_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_stats_label.text = (
		"RAM %d   CPU %d   STO %d   Cycles %d"
		% [GameState.ram, GameState.cpu, GameState.sto, GameState.cycles]
	)
	_tier_label.text = "T%d" % tier
	var type: String = TYPES[type_index]
	_type_button.text = "Minigame: %s" % SlotDef.TYPE_NAMES[type]
	var mod: String = _modifiers()[modifier_index]
	_modifier_button.text = "Modifier: %s" % ("none" if mod.is_empty() else mod.capitalize())
	_play_button.text = "Play %s T%d" % [SlotDef.TYPE_NAMES[type], tier]
	_play_button.add_theme_color_override("font_color", get_theme_color(type, "Hardwire"))
	_scale_button.text = "Time scale: %sx" % Engine.time_scale


## "" plus the selected minigame's modifier pool from balance.json.
func _modifiers() -> Array[String]:
	var mods: Array[String] = [""]
	for m: Variant in Balance.modifiers().get("pools", {}).get(TYPES[type_index], []):
		mods.append(str(m))
	return mods


func _change_tier(delta: int) -> void:
	_set_tier(tier + delta)


func _set_tier(t: int) -> void:
	tier = maxi(1, t)
	_refresh()


func _cycle_type() -> void:
	type_index = (type_index + 1) % TYPES.size()
	modifier_index = 0
	_refresh()


func _cycle_modifier() -> void:
	modifier_index = (modifier_index + 1) % _modifiers().size()
	_refresh()


func _cycle_time_scale() -> void:
	var scales: Array = Balance.section("debug").get("time_scales", [1])
	var i: int = scales.find(Engine.time_scale)
	Engine.time_scale = float(scales[(i + 1) % scales.size()])
	_refresh()


func _add_stats(step: int) -> void:
	GameState.add_stats(step, step, step)
	SaveManager.save_game()


func _add_cycles() -> void:
	GameState.cycles += Balance.get_int("debug", "cycles_step")
	GameState.cycles_changed.emit()
	SaveManager.save_game()


func _set_stats_for_tier() -> void:
	var r: int = Balance.req(tier)
	GameState.add_stats(r - GameState.ram, r - GameState.cpu, r - GameState.sto)
	SaveManager.save_game()


## The tier's real slot (requirements and rewards), with the picked modifier forced.
func _on_play() -> void:
	var slot: SlotDef = SlotGenerator.make(tier, TYPES[type_index])
	slot.modifier = _modifiers()[modifier_index]
	play_requested.emit(slot)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire") / 2)
	parent.add_child(row)
	return row


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	var tap: float = get_theme_constant("tap_min", "Hardwire")
	button.custom_minimum_size = Vector2(tap * 1.5, tap)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_pressed)
	return button
