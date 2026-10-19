class_name OverviewScreen
extends Control
## Overview hub (SPEC: Screens and UX flow): stat bar, scrolling list of tier rows (every unlocked
## tier plus flow.locked_tiers_visible locked ones), bottom bar with Shop, Rebuild and Settings.

signal play_requested(slot: SlotDef)
signal shop_requested
signal settings_requested
signal debug_requested

var rebuild_button: Button
var shop_button: Button

var _scroll: ScrollContainer
var _list: VBoxContainer
var _rows: Array[TierRow] = []
var _scroll_frames: int = 2


func _ready() -> void:
	var landscape: bool = Ui.is_landscape(self)
	# Portrait: stats on top, list, buttons at the bottom.
	# Landscape: a sidebar with stats and buttons beside the list.
	var body: BoxContainer = Ui.box(not landscape)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Ui.screen_root(self).add_child(body)
	var side: BoxContainer = body
	if landscape:
		side = Ui.box(true)
		side.custom_minimum_size.x = get_theme_constant("side_panel", "Hardwire")
		body.add_child(side)
	var stat_bar := StatBar.new()
	stat_bar.vertical = landscape
	stat_bar.debug_requested.connect(debug_requested.emit)
	side.add_child(stat_bar)
	if landscape:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.add_child(spacer)
	body.add_child(_build_list())
	side.add_child(_build_buttons(landscape))
	GameState.stats_changed.connect(_sync_rows)
	GameState.upgrades_changed.connect(_refresh_rows)
	GameState.cores_changed.connect(_refresh_rows)
	_sync_rows()


func _build_list() -> ScrollContainer:
	_scroll = Ui.scroll()
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire"))
	_scroll.add_child(_list)
	return _scroll


func _build_buttons(vertical: bool) -> BoxContainer:
	var bar: BoxContainer = Ui.box(vertical)
	shop_button = Ui.button("Shop", shop_requested.emit)
	rebuild_button = Ui.button("Rebuild", _confirm_rebuild)
	var buttons: Array[Button] = [
		shop_button, rebuild_button, Ui.button("Settings", settings_requested.emit)
	]
	if OS.has_feature("pc"):
		buttons.append(Ui.button("Quit", _quit))
	for button: Button in buttons:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(button)
	return bar


## PC only (SPEC: Overview, D-025): phones leave through the Android back button.
func _quit() -> void:
	SaveManager.save_game()
	get_tree().quit()


## Gamepad focus on open: the first unsolved slot of the newest unlocked tier, else its first slot.
func default_focus() -> Control:
	var newest: int = Progress.highest_unlocked_tier(GameState.stats())
	if newest > _rows.size():
		return null
	var cards: Array[SlotCard] = _rows[newest - 1].cards
	for card: SlotCard in cards:
		if not GameState.is_solved(card.slot):
			return card
	return cards[0]


func rows() -> Array[TierRow]:
	return _rows


## Number of tier rows to show: every unlocked tier plus the next locked ones.
static func visible_tiers() -> int:
	return (
		Progress.highest_unlocked_tier(GameState.stats())
		+ Balance.get_int("flow", "locked_tiers_visible")
	)


## Adds or removes tier rows until the list shows visible_tiers() of them.
func _sync_rows() -> void:
	var count: int = visible_tiers()
	while _rows.size() < count:
		var row := TierRow.new()
		row.setup(_rows.size() + 1)
		row.slot_pressed.connect(play_requested.emit)
		_list.add_child(row)
		_rows.append(row)
	while _rows.size() > count:
		_rows.pop_back().queue_free()
	_refresh_rows()


## Confirm dialog with Cores to gain and the new multiplier, then the prestige (SPEC: Prestige).
func _confirm_rebuild() -> void:
	var gained: int = Progress.rebuild_cores(GameState.solved_slots)
	var message: String = (
		"Gain %d %s: rewards x%s -> x%s.\nStats, Cycles, upgrades and first solves reset."
		% [
			gained,
			"Core" if gained == 1 else "Cores",
			Economy.core_multiplier(GameState.cores),
			Economy.core_multiplier(GameState.cores + gained)
		]
	)
	var dialog := ConfirmDialog.open(self, "Rebuild?", message, "Rebuild")
	dialog.confirmed.connect(
		func() -> void:
			GameState.rebuild()
			SaveManager.save_game()
	)


func _refresh_rows() -> void:
	for row: TierRow in _rows:
		row.refresh()
	rebuild_button.disabled = not Progress.can_rebuild(GameState.solved_slots)


## Brings the newest unlocked tier into view once the layout has settled.
func _process(_delta: float) -> void:
	if _scroll_frames <= 0:
		return
	_scroll_frames -= 1
	if _scroll_frames == 0:
		var newest: int = Progress.highest_unlocked_tier(GameState.stats())
		if newest - 1 < _rows.size():
			_scroll.ensure_control_visible(_rows[newest - 1])
