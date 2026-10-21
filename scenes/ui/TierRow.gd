class_name TierRow
extends VBoxContainer
## One tier on the overview: a trace node (outlined while locked, filled when unlocked, accent once
## every slot is solved), tier number, a rule, requirement chips (attention colour while unmet)
## and 3 slot cards joined by thin traces. A trace line on the left connects the rows (D-041).

signal slot_pressed(slot: SlotDef)

enum NodeState { LOCKED, OPEN, SOLVED }

var tier: int = 1
var cards: Array[SlotCard] = []

## Requirement chips, one per SlotGenerator.TYPES entry, in that order.
var _chips: Array[Label] = []
var _header: HBoxContainer
var _row: HBoxContainer


func _init(p_tier: int = 1) -> void:
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
	var rule := HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(rule)
	for type: String in SlotGenerator.TYPES:
		var chip := Label.new()
		chip.text = "%s %d" % [SlotDef.STAT_NAMES[type], Balance.req(tier)]
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
		_header.add_child(chip)
		_chips.append(chip)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", gap)
	add_child(_row)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = _spacer_width()
	_row.add_child(spacer)
	for slot: SlotDef in SlotGenerator.tier_slots(tier):
		var card := SlotCard.new()
		card.setup(slot)
		card.pressed.connect(func() -> void: slot_pressed.emit(slot))
		_row.add_child(card)
		cards.append(card)
	refresh()


func refresh() -> void:
	for i: int in _chips.size():
		var type: String = SlotGenerator.TYPES[i]
		var met: bool = GameState.stats()[type] >= Balance.req(tier)
		_chips[i].add_theme_color_override(
			"font_color", get_theme_color("text_dim" if met else "warn", "Hardwire")
		)
	for card: SlotCard in cards:
		card.refresh()
	queue_redraw()


## Locked until the tier opens, solved once all three slots are.
func node_state() -> NodeState:
	if cards.is_empty() or cards[0].disabled:
		return NodeState.LOCKED
	for card: SlotCard in cards:
		if not GameState.is_solved(card.slot):
			return NodeState.OPEN
	return NodeState.SOLVED


## Trace line down the left edge, the tier's node with a stub to its label, and traces between
## the cards (SPEC: Overview; D-041).
func _draw() -> void:
	var trace: Color = get_theme_color("trace", "Hardwire")
	var margin: float = get_theme_constant("margin", "Hardwire")
	var x: float = _spacer_width() / 2
	var width: float = get_theme_constant("trace_width", "Hardwire")
	var lamp: float = get_theme_constant("lamp_size", "Hardwire")
	var y: float = _header.size.y / 2
	draw_line(Vector2(x, 0), Vector2(x, size.y + margin), trace, width)
	draw_line(Vector2(x, y), Vector2(_spacer_width() + margin / 2, y), trace, width)
	var state: NodeState = node_state()
	var node := Rect2(Vector2(x - lamp / 2, y - lamp / 2), Vector2(lamp, lamp))
	if state == NodeState.LOCKED:
		draw_rect(node, trace, false, get_theme_constant("outline_width", "Hardwire"))
	else:
		draw_rect(
			node, get_theme_color("accent", "Hardwire") if state == NodeState.SOLVED else trace
		)
	for i: int in cards.size() - 1:
		var from: Rect2 = cards[i].get_rect()
		var to: Rect2 = cards[i + 1].get_rect()
		var mid: float = _row.position.y + from.position.y + from.size.y / 2
		draw_line(Vector2(from.end.x, mid), Vector2(to.position.x, mid), trace, width)


## Empty strip left of the cards that the trace line runs through.
func _spacer_width() -> float:
	return get_theme_constant("margin", "Hardwire") / 2.0
