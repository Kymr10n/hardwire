class_name TierRow
extends VBoxContainer
## One tier on the overview: tier number, requirement chips (accent while unmet) and 3 slot cards.
## A thin trace line on the left connects the rows (SPEC: Visual style).

signal slot_pressed(slot: SlotDef)

var tier: int = 1
var cards: Array[SlotCard] = []

var _chips: Array[Label] = []
var _header: HBoxContainer


func setup(p_tier: int) -> void:
	tier = p_tier


func _ready() -> void:
	var margin: int = get_theme_constant("margin", "Hardwire")
	var gap: int = get_theme_constant("row_gap", "Hardwire")
	add_theme_constant_override("separation", gap)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", margin / 2)
	add_child(_header)
	var title := Label.new()
	title.text = "  T%d" % tier
	title.custom_minimum_size.x = get_theme_constant("tier_label_width", "Hardwire")
	title.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	_header.add_child(title)
	for type: String in SlotGenerator.TYPES:
		var chip := Label.new()
		chip.text = "%s %d" % [SlotDef.STAT_NAMES[type], Balance.req(tier)]
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
		chip.set_meta("type", type)
		_header.add_child(chip)
		_chips.append(chip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = _spacer_width()
	row.add_child(spacer)
	for slot: SlotDef in SlotGenerator.tier_slots(tier):
		var card := SlotCard.new()
		card.setup(slot)
		card.pressed.connect(func() -> void: slot_pressed.emit(slot))
		row.add_child(card)
		cards.append(card)
	refresh()


func refresh() -> void:
	for chip: Label in _chips:
		var type: String = chip.get_meta("type")
		var met: bool = GameState.stats()[type] >= Balance.req(tier)
		chip.add_theme_color_override(
			"font_color",
			get_theme_color("text_dim", "Hardwire") if met else get_theme_color(type, "Hardwire")
		)
	for card: SlotCard in cards:
		card.refresh()
	queue_redraw()


## Trace line down the left edge with a node at the tier label (SPEC: Visual style).
func _draw() -> void:
	var trace: Color = get_theme_color("trace", "Hardwire")
	var margin: float = get_theme_constant("margin", "Hardwire")
	var x: float = _spacer_width() / 2
	var width: float = get_theme_constant("trace_width", "Hardwire")
	draw_line(Vector2(x, 0), Vector2(x, size.y + margin), trace, width)
	draw_circle(Vector2(x, _header.size.y / 2), x, trace)


## Empty strip left of the cards that the trace line runs through.
func _spacer_width() -> float:
	return get_theme_constant("margin", "Hardwire") / 2.0
