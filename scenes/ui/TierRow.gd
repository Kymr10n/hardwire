class_name TierRow
extends VBoxContainer
## One tier on the overview: tier number, requirement chips (accent stickers while unmet) and 3
## slot cards, a drive-bay stack under a vent row (the front panel has its own above tier 1).

signal slot_pressed(slot: SlotDef)

var tier: int = 1
var cards: Array[SlotCard] = []

## Requirement chips, one per SlotGenerator.TYPES entry, in that order.
var _chips: Array[Label] = []
var _header: HBoxContainer


func _init(p_tier: int = 1) -> void:
	tier = p_tier


func _ready() -> void:
	var margin: int = get_theme_constant("margin", "Hardwire")
	var gap: int = get_theme_constant("row_gap", "Hardwire")
	add_theme_constant_override("separation", gap)
	if tier > 1:
		add_child(Deco.vent())
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", margin / 2)
	add_child(_header)
	var title := Label.new()
	title.text = "T%d" % tier
	title.custom_minimum_size.x = get_theme_constant("tier_label_width", "Hardwire")
	title.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	_header.add_child(title)
	for type: String in SlotGenerator.TYPES:
		var chip := Label.new()
		chip.text = "%s %d" % [SlotDef.STAT_NAMES[type], Balance.req(tier)]
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
		Ui.make_sticker(chip)
		_header.add_child(chip)
		_chips.append(chip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	add_child(row)
	for slot: SlotDef in SlotGenerator.tier_slots(tier):
		var card := SlotCard.new()
		card.setup(slot)
		card.pressed.connect(func() -> void: slot_pressed.emit(slot))
		row.add_child(card)
		cards.append(card)
	refresh()


func refresh() -> void:
	for i: int in _chips.size():
		var type: String = SlotGenerator.TYPES[i]
		var met: bool = GameState.stats()[type] >= Balance.req(tier)
		Ui.sticker_color(_chips[i], Color.TRANSPARENT if met else get_theme_color(type, "Hardwire"))
	for card: SlotCard in cards:
		card.refresh()
