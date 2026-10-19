extends Control
## Developer entry screen until the overview exists (M5): stats, a debug stat button,
## and a launcher for each minigame with a tier picker and a forced-modifier picker.

signal play_requested(slot: SlotDef)

const QUICK_TIERS: Array[int] = [1, 5, 10, 20]

## Minigames that can be launched so far, in menu order.
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: int = get_theme_constant("margin", "Hardwire")
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", margin)
	add_child(box)

	var title := _label("HARDWIRE", get_theme_font_size("title", "Hardwire"))
	title.add_theme_color_override("font_color", get_theme_color("ram", "Hardwire"))
	box.add_child(title)
	_stats_label = _label("", 0)
	box.add_child(_stats_label)
	if OS.is_debug_build():
		box.add_child(_button("+%d all stats" % Balance.get_int("debug", "stat_step"), _on_add_stats))

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

	_type_button = _button("", _cycle_type)
	box.add_child(_type_button)
	_modifier_button = _button("", _cycle_modifier)
	box.add_child(_modifier_button)
	_play_button = _button("Play", _on_play)
	box.add_child(_play_button)

	GameState.stats_changed.connect(_refresh)
	GameState.cycles_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_stats_label.text = "RAM %d   CPU %d   STO %d   Cycles %d" % [GameState.ram, GameState.cpu, GameState.sto, GameState.cycles]
	_tier_label.text = "T%d" % tier
	var type: String = TYPES[type_index]
	_type_button.text = "Minigame: %s" % SlotDef.TYPE_NAMES[type]
	var mod: String = _modifiers()[modifier_index]
	_modifier_button.text = "Modifier: %s" % ("none" if mod.is_empty() else mod.capitalize())
	_play_button.text = "Play %s" % SlotDef.TYPE_NAMES[type]
	_play_button.add_theme_color_override("font_color", get_theme_color(type, "Hardwire"))


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


func _on_add_stats() -> void:
	var step: int = Balance.get_int("debug", "stat_step")
	GameState.add_stats(step, step, step)
	SaveManager.save_game()


func _on_play() -> void:
	play_requested.emit(SlotDef.create(tier, TYPES[type_index], _modifiers()[modifier_index]))


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
