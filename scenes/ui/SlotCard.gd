class_name SlotCard
extends Button
## One slot on the overview (SPEC: Slot card states), a drive-bay device (DESIGN: Cards): locked
## (blanking plate stamped EMPTY BAY, missing stats), unlocked and never solved (accent border,
## NEW sticker), solved (normal), modifier (icon in the corner). Shows what the next solve pays
## on a recessed screen. Labels in containers on a Button styled per state.

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
const PRESSED_DARKEN := 0.08

var slot: SlotDef

var lines: Label
var badge_new: Label
var modifier_label: Label
var _style: BevelBox
var _pressed_style: BevelBox
var _screen: PanelContainer
var _content: MarginContainer
var _stamp: Label
var _title: Label
var _glyph: Label


func _init() -> void:
	# A swipe that starts on a card must reach the overview's ScrollContainer (which cancels the
	# press when it starts scrolling); a Button would swallow it.
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(p_slot: SlotDef) -> void:
	slot = p_slot
	text = ""
	custom_minimum_size = Vector2(0, get_theme_constant("tap_min", "Hardwire") * HEIGHT_TAPS)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style = get_theme_stylebox("bay", "Hardwire").duplicate()
	_pressed_style = _style.duplicate()
	_pressed_style.sunken = true
	_pressed_style.bg = _style.bg.darkened(PRESSED_DARKEN)
	for state: String in ["normal", "hover"]:
		add_theme_stylebox_override(state, _style)
	add_theme_stylebox_override("pressed", _pressed_style)
	add_theme_stylebox_override("disabled", get_theme_stylebox("plate", "Hardwire"))
	button_down.connect(_press.bind(true))
	button_up.connect(_press.bind(false))
	_build()
	refresh()


func refresh() -> void:
	var locked: bool = not Progress.is_unlocked(slot.req, GameState.stats())
	var solved: bool = GameState.is_solved(slot)
	var accent: Color = get_theme_color(slot.type, "Hardwire")
	var dim: Color = get_theme_color("text_dim", "Hardwire")
	disabled = locked
	# A never-solved bay has a lit (accent) frame instead of the plastic bevel.
	var lit: bool = not locked and not solved
	for style: BevelBox in [_style, _pressed_style]:
		style.light = accent if lit else get_theme_color("plastic_light", "Hardwire")
		style.dark = accent if lit else get_theme_color("plastic_dark", "Hardwire")
	_screen.add_theme_stylebox_override(
		"panel", StyleBoxEmpty.new() if locked else get_theme_stylebox("recess", "Hardwire")
	)
	Ui.sticker_color(_title, dim if locked else accent)
	_glyph.visible = not slot.modifier.is_empty()
	_glyph.text = MOD_GLYPHS.get(slot.modifier, "*")
	Ui.sticker_color(_glyph, dim if locked else accent)
	modifier_label.text = SlotDef.modifier_name(slot.modifier)
	lines.text = _missing_text() if locked else _reward_text(not solved)
	_stamp.visible = locked
	lines.add_theme_color_override(
		"font_color", dim if locked else get_theme_color("text", "Hardwire")
	)
	badge_new.visible = not locked and not solved
	Ui.sticker_color(badge_new, accent)


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


## The content goes in with the keycap: down by the bevel at once, back over press_out_ms.
func _press(down: bool) -> void:
	var offset: float = get_theme_constant("bevel", "Hardwire") if down else 0.0
	var tween := create_tween()
	if down:
		tween.tween_property(_content, "offset_top", offset, 0.0)
	else:
		tween.tween_property(
			_content, "offset_top", offset, get_theme_constant("press_out_ms", "Hardwire") / 1000.0
		)
	tween.parallel().tween_property(
		_content, "offset_bottom", offset, tween.get_total_elapsed_time()
	)


func _build() -> void:
	_content = MarginContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad: int = int(get_theme_constant("margin", "Hardwire") * PAD)
	for side: String in ["left", "top", "right", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, pad)
	add_child(_content)
	var column := VBoxContainer.new()
	_content.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_title = _add_label(top, SlotDef.TYPE_NAMES[slot.type], "card_title", false)
	_title.uppercase = true
	Ui.make_sticker(_title)
	var bay: int = (
		(slot.tier - 1) * SlotGenerator.TYPES.size() + SlotGenerator.TYPES.find(slot.type) + 1
	)
	var designator: Label = Ui.sticker("BAY %d" % bay)
	designator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(designator)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	_glyph = _add_label(top, "", "small", false)
	Ui.make_sticker(_glyph)
	_screen = PanelContainer.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_screen)
	lines = _add_label(_screen, "", "card_body", false)
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	modifier_label = _add_label(bottom, "", "small", true)
	modifier_label.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	_stamp = _add_label(bottom, "EMPTY BAY", "small", false)
	_stamp.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	badge_new = _add_label(bottom, "NEW", "small", false)
	Ui.make_sticker(badge_new)


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
