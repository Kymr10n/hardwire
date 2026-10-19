extends Control
## Upgrade shop (SPEC: Upgrade shop): Cycles balance on top, one card per upgrade. Saves after a purchase.

signal exit_requested

var cards: Array[UpgradeCard] = []

var _balance: Label


func _ready() -> void:
	var margin: int = get_theme_constant("margin", "Hardwire")
	var column: VBoxContainer = Ui.screen_root(self)
	_balance = Ui.header(column, "", exit_requested.emit)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	# One column in portrait, two in landscape.
	var list := GridContainer.new()
	list.columns = 2 if Ui.is_landscape(self) else 1
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("h_separation", margin / 2)
	list.add_theme_constant_override("v_separation", margin / 2)
	scroll.add_child(list)
	for id: String in Balance.upgrade_ids():
		var card := UpgradeCard.new()
		card.setup(id)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
