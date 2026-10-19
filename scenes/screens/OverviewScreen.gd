extends Control
## Overview hub (SPEC: Screens and UX flow): stat bar, scrolling list of tier rows (every unlocked
## tier plus flow.locked_tiers_visible locked ones), bottom bar with Shop, Rebuild and Settings.

signal play_requested(slot: SlotDef)
signal shop_requested
signal rebuild_requested
signal settings_requested
signal debug_requested

var _scroll: ScrollContainer
var _list: VBoxContainer
var _rows: Array[TierRow] = []
var _scroll_frames: int = 2
var rebuild_button: Button
var shop_button: Button


func _ready() -> void:
	var margin: int = get_theme_constant("margin", "Hardwire")
	var landscape: bool = Ui.is_landscape(self)
	var root: VBoxContainer = Ui.screen_root(self)

	# Portrait: stats on top, list, buttons at the bottom.
	# Landscape: a sidebar with stats and buttons beside the list.
	var body := BoxContainer.new()
	body.vertical = not landscape
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", margin / 2)
	root.add_child(body)
	var side: BoxContainer = body
	if landscape:
		side = VBoxContainer.new()
		side.custom_minimum_size.x = get_theme_constant("side_panel", "Hardwire")
		side.add_theme_constant_override("separation", margin / 2)
		body.add_child(side)

	var stat_bar := StatBar.new()
	stat_bar.vertical = landscape
	stat_bar.debug_requested.connect(debug_requested.emit)
	side.add_child(stat_bar)
	if landscape:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.add_child(spacer)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", margin)
	_scroll.add_child(_list)

	var bottom := BoxContainer.new()
	bottom.vertical = landscape
	bottom.add_theme_constant_override("separation", margin / 2)
	side.add_child(bottom)
	shop_button = _bottom_button("Shop", shop_requested.emit)
	bottom.add_child(shop_button)
	rebuild_button = _bottom_button("Rebuild", rebuild_requested.emit)
	bottom.add_child(rebuild_button)
	bottom.add_child(_bottom_button("Settings", settings_requested.emit))

	GameState.stats_changed.connect(_rebuild_rows)
	GameState.upgrades_changed.connect(_refresh_rows)
	GameState.cores_changed.connect(_refresh_rows)
	_rebuild_rows()


func rows() -> Array[TierRow]:
	return _rows


## Number of tier rows to show: every unlocked tier plus the next locked ones.
static func visible_tiers() -> int:
	return GameState.highest_unlocked_tier() + Balance.get_int("flow", "locked_tiers_visible")


func _rebuild_rows() -> void:
	var count: int = visible_tiers()
	while _rows.size() < count:
		var row := TierRow.new()
		row.setup(_rows.size() + 1)
		row.slot_pressed.connect(play_requested.emit)
		_list.add_child(row)
		_rows.append(row)
	_refresh_rows()


func _refresh_rows() -> void:
	for row: TierRow in _rows:
		row.refresh()
	rebuild_button.disabled = not _rebuild_available()


## Rebuild needs a solved slot at economy.prestige_min_tier or above (SPEC: Prestige).
func _rebuild_available() -> bool:
	return GameState.highest_solved_tier() >= Balance.get_int("economy", "prestige_min_tier")


## Brings the newest unlocked tier into view once the layout has settled.
func _process(_delta: float) -> void:
	if _scroll_frames <= 0:
		return
	_scroll_frames -= 1
	if _scroll_frames == 0:
		var newest: int = GameState.highest_unlocked_tier()
		if newest - 1 < _rows.size():
			_scroll.ensure_control_visible(_rows[newest - 1])


func _bottom_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = get_theme_constant("tap_min", "Hardwire")
	button.pressed.connect(on_pressed)
	return button
