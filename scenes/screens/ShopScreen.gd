extends Control
## Upgrade shop (SPEC: Upgrade shop): Cycles balance on top, one card per upgrade. Saves after a purchase.

signal exit_requested

var cards: Array[UpgradeCard] = []

var _balance: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: int = get_theme_constant("margin", "Hardwire")
	var tap: float = get_theme_constant("tap_min", "Hardwire")
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + side, margin / 2)
	add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", margin / 2)
	root.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var back := Button.new()
	back.text = "< Back"
	back.custom_minimum_size = Vector2(tap * 1.5, tap)
	back.pressed.connect(exit_requested.emit)
	header.add_child(back)
	_balance = Label.new()
	_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_balance.add_theme_font_size_override("font_size", get_theme_font_size("header", "Hardwire"))
	header.add_child(_balance)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", margin / 2)
	scroll.add_child(list)
	for id: String in Balance.upgrade_ids():
		var card := UpgradeCard.new()
		card.setup(id)
		card.buy_pressed.connect(_on_buy)
		list.add_child(card)
		cards.append(card)

	GameState.cycles_changed.connect(_refresh)
	GameState.upgrades_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_balance.text = "%d Cycles" % GameState.cycles
	for card: UpgradeCard in cards:
		if card.is_node_ready():
			card.refresh()


func _on_buy(id: String) -> void:
	if GameState.buy_upgrade(id):
		Haptics.pulse()
		Synth.play_click()
		SaveManager.save_game()
