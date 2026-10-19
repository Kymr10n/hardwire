class_name TierRow
extends VBoxContainer
## One tier on the overview: tier number, requirement chips (accent while unmet) and 3 slot cards.
## A thin trace line on the left connects the rows (SPEC: Visual style).

signal slot_pressed(slot: SlotDef)

var tier: int = 1
var cards: Array[SlotCard] = []

var _chips: Array[Label] = []


func setup(p_tier: int) -> void:
	tier = p_tier


func _ready() -> void:
	var margin: int = get_theme_constant("margin", "Hardwire")
	add_theme_constant_override("separation", margin / 3)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", margin / 2)
	add_child(header)
	var title := Label.new()
	title.text = "  T%d" % tier
	title.custom_minimum_size.x = 130
	title.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	header.add_child(title)
	for type: String in SlotGenerator.TYPES:
		var chip := Label.new()
		chip.text = "%s %d" % [SlotDef.STAT_NAMES[type], Balance.req(tier)]
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
		chip.set_meta("type", type)
		header.add_child(chip)
		_chips.append(chip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", margin / 3)
	add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 24
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
		var met: bool = GameState.stat(type) >= Balance.req(tier)
		chip.add_theme_color_override(
			"font_color",
			get_theme_color("text_dim", "Hardwire") if met else get_theme_color(type, "Hardwire")
		)
	for card: SlotCard in cards:
		card.refresh()
	queue_redraw()


func _draw() -> void:
	var trace: Color = get_theme_color("trace", "Hardwire")
	draw_line(
		Vector2(8, 0), Vector2(8, size.y + get_theme_constant("margin", "Hardwire")), trace, 3.0
	)
	draw_circle(Vector2(8, 30), 8, trace)
