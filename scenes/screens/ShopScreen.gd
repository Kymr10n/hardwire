class_name ShopScreen
extends Control
## Upgrade shop (SPEC: Upgrade shop), a parts catalog (DESIGN: Shop): Cycles balance on top, one
## card per upgrade with its part number. Saves after a purchase.

signal exit_requested

var cards: Array[UpgradeCard] = []

var _balance: Label


func _ready() -> void:
	var margin: int = get_theme_constant("margin", "Hardwire")
	var column: VBoxContainer = Ui.screen_root(self)
	Ui.header(column, "Parts & upgrades", exit_requested.emit)
	_balance = Ui.readout("", "led_amber")
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_balance)

	var scroll: ScrollContainer = Ui.scroll()
	column.add_child(scroll)
	# One column in portrait, two in landscape.
	var list := GridContainer.new()
	list.columns = 2 if Ui.is_landscape(self) else 1
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("h_separation", margin / 2)
	list.add_theme_constant_override("v_separation", margin / 2)
	scroll.add_child(list)
	for id: String in Balance.upgrade_ids():
		var card := UpgradeCard.new(id)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.buy_pressed.connect(_on_buy)
		list.add_child(card)
		cards.append(card)

	column.add_child(Ui.sticker(Ui.FINE_PRINT))
	GameState.cycles_changed.connect(_refresh)
	GameState.upgrades_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_balance.text = "%d CYC" % GameState.cycles
	for card: UpgradeCard in cards:
		card.refresh()


func _on_buy(id: String) -> void:
	if GameState.buy_upgrade(id):
		Synth.play_click()
		SaveManager.save_game()
