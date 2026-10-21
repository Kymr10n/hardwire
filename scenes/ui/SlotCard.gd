class_name SlotCard
extends Button
## One slot on the overview (SPEC: Slot card states): locked (greyed, LOCKED tag, missing stats),
## unlocked and never solved (stat-hue border, NEW tag), solved (normal), modifier (icon in the
## corner). Shows what the next solve pays. Labels in containers on a Button styled per state.

const MOD_GLYPHS := {
	"reverse": "<",
	"decoy": "?",
	"inverted": "~",
	"rotated": "R",
	"audio_only": "A",
	"syncopated": "S",
}

const HEIGHT_TAPS := 2.2
## A locked card stacks the modifier name over the LOCKED tag (both would not fit one row on a
## phone), so it is taller; a tier's three cards are always locked together.
const LOCKED_HEIGHT_TAPS := 2.4
const PAD := 0.4

var slot: SlotDef

var lines: Label
var badge_new: Label
var tag_locked: Label
var modifier_label: Label
var _style := StyleBoxFlat.new()
var _pressed_style := StyleBoxFlat.new()
var _title: Label
var _glyph: Label
var _bottom: BoxContainer


func _init() -> void:
	# A swipe that starts on a card must reach the overview's ScrollContainer (which cancels the
	# press when it starts scrolling); a Button would swallow it.
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(p_slot: SlotDef) -> void:
	slot = p_slot
	text = ""
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state: String in ["normal", "hover", "disabled"]:
		add_theme_stylebox_override(state, _style)
	add_theme_stylebox_override("pressed", _pressed_style)
	_build()
	refresh()


func refresh() -> void:
	var locked: bool = not Progress.is_unlocked(slot.req, GameState.stats())
	var solved: bool = GameState.is_solved(slot)
	var hue: Color = get_theme_color(slot.type, "Hardwire")
	var dim: Color = get_theme_color("text_dim", "Hardwire")
	disabled = locked
	_bottom.vertical = locked
	custom_minimum_size.y = (
		get_theme_constant("tap_min", "Hardwire") * (LOCKED_HEIGHT_TAPS if locked else HEIGHT_TAPS)
	)
	_style.bg_color = get_theme_color("card_locked" if locked else "card", "Hardwire")
	var fresh: bool = not locked and not solved
	_style.border_color = hue if fresh else get_theme_color("trace", "Hardwire")
	_style.set_border_width_all(
		get_theme_constant("outline_new_width" if fresh else "outline_width", "Hardwire")
	)
	_pressed_style.set_border_width_all(_style.border_width_left)
	_pressed_style.border_color = _style.border_color
	_pressed_style.bg_color = get_theme_color("raised", "Hardwire")
	_title.add_theme_color_override("font_color", dim if locked else hue)
	_glyph.visible = not slot.modifier.is_empty()
	_glyph.text = MOD_GLYPHS.get(slot.modifier, "*")
	Ui.tag(_glyph, dim if locked else hue)
	modifier_label.text = SlotDef.modifier_name(slot.modifier)
	lines.text = _missing_text() if locked else _reward_text(not solved)
	lines.add_theme_color_override(
		"font_color", dim if locked else get_theme_color("text", "Hardwire")
	)
	badge_new.visible = fresh
	tag_locked.visible = locked


## "CPU 4 more" per missing stat.
func _missing_text() -> String:
	var missing: Dictionary = Progress.missing(slot.req, GameState.stats())
	var lines: Array[String] = []
	for type: String in SlotGenerator.TYPES:
		if missing.has(type):
			lines.append("%s %d more" % [SlotDef.STAT_NAMES[type], missing[type]])
	return "\n".join(lines)


## What the next solve pays.
func _reward_text(first_solve: bool) -> String:
	var gain: Dictionary = Economy.solve_reward(
		slot,
		first_solve,
		GameState.upgrade_level("overclock"),
		GameState.upgrade_level("cycle_miner"),
		GameState.cores
	)
	return "+%d %s\n+%d Cyc" % [gain.stat, SlotDef.STAT_NAMES[slot.type], gain.cycles]


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad: int = int(get_theme_constant("margin", "Hardwire") * PAD)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, pad)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_title = _add_label(top, SlotDef.TYPE_NAMES[slot.type], "card_title", true)
	_glyph = _add_label(top, "", "small", false)
	lines = _add_label(column, "", "card_body", false)
	lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom = BoxContainer.new()
	column.add_child(_bottom)
	modifier_label = _add_label(_bottom, "", "small", true)
	modifier_label.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	badge_new = _add_label(_bottom, "NEW", "small", false)
	Ui.tag(badge_new, get_theme_color(slot.type, "Hardwire"))
	tag_locked = _add_label(_bottom, "LOCKED", "small", false)
	tag_locked.size_flags_horizontal = Control.SIZE_SHRINK_END
	Ui.tag(tag_locked, get_theme_color("text_dim", "Hardwire"), false)


func _add_label(parent: Control, text: String, font: String, expand: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", get_theme_font_size(font, "Hardwire"))
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
	parent.add_child(l)
	return l
