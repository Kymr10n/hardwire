class_name SlotCard
extends Button
## One slot on the overview (SPEC: Slot card states): locked (greyed, missing stats), unlocked and
## never solved (accent border, NEW badge), solved (normal), modifier (icon in the corner). Shows
## what the next solve pays. Labels in containers on a Button styled per state.

const MOD_GLYPHS := {
	"reverse": "<",
	"decoy": "?",
	"inverted": "~",
	"rotated": "R",
	"audio_only": "A",
	"syncopated": "S",
}

const HEIGHT_TAPS := 2.2
const PAD := 0.4
const CORNER := 18
const BORDER := 2
const BORDER_NEW := 4
const BADGE_CORNER := 10
const BADGE_PAD := 10.0
const PRESSED_LIGHTEN := 0.08

var slot: SlotDef

var _style := StyleBoxFlat.new()
var _pressed_style := StyleBoxFlat.new()
var _title: Label
var _glyph: Label
var _lines: Label
var _modifier: Label
var _new: Label


func setup(p_slot: SlotDef) -> void:
	slot = p_slot
	flat = true
	text = ""
	custom_minimum_size = Vector2(0, get_theme_constant("tap_min", "Hardwire") * HEIGHT_TAPS)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state: String in ["normal", "hover", "disabled"]:
		add_theme_stylebox_override(state, _style)
	add_theme_stylebox_override("pressed", _pressed_style)
	_build()
	refresh()


func refresh() -> void:
	var locked: bool = not Progress.is_unlocked(slot.req, GameState.stats())
	var solved: bool = GameState.is_solved(slot)
	var accent: Color = get_theme_color(slot.type, "Hardwire")
	var dim: Color = get_theme_color("text_dim", "Hardwire")
	disabled = locked
	_style.bg_color = get_theme_color("card_locked" if locked else "card", "Hardwire")
	_style.border_color = (
		accent if not locked and not solved else get_theme_color("trace", "Hardwire")
	)
	_style.set_border_width_all(BORDER_NEW if not locked and not solved else BORDER)
	_pressed_style.set_border_width_all(_style.border_width_left)
	_pressed_style.set_corner_radius_all(CORNER)
	_pressed_style.border_color = _style.border_color
	_pressed_style.bg_color = _style.bg_color.lightened(PRESSED_LIGHTEN)
	_title.add_theme_color_override("font_color", dim if locked else accent)
	_glyph.visible = not slot.modifier.is_empty()
	_glyph.text = MOD_GLYPHS.get(slot.modifier, "*")
	_badge_style(_glyph, dim if locked else accent)
	_modifier.text = slot.modifier.capitalize()
	_lines.text = _missing_text() if locked else _reward_text(not solved)
	_lines.add_theme_color_override(
		"font_color", dim if locked else get_theme_color("text", "Hardwire")
	)
	_new.visible = not locked and not solved
	_badge_style(_new, accent)


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
	_style.set_corner_radius_all(CORNER)
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
	_lines = _add_label(column, "", "card_body", false)
	_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	_modifier = _add_label(bottom, "", "small", true)
	_modifier.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	_new = _add_label(bottom, "NEW", "small", false)


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


## Small filled pill behind a badge label (modifier glyph, NEW).
func _badge_style(badge: Label, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(BADGE_CORNER)
	style.content_margin_left = BADGE_PAD
	style.content_margin_right = BADGE_PAD
	badge.add_theme_stylebox_override("normal", style)
	badge.add_theme_color_override("font_color", get_theme_color("bg", "Hardwire"))
