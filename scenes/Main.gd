extends Control
## Root scene. Holds the current screen and handles transitions (SPEC: Screens and UX flow):
## Boot -> Overview hub -> Puzzle / Shop / Settings / debug panel, plus the Rebuild dialog and
## the "While you were away" idle income dialog (on start and after a resume, shown on the overview).

const BootScreen := preload("res://scenes/screens/BootScreen.gd")
const OverviewScreen := preload("res://scenes/screens/OverviewScreen.gd")
const PuzzleScreen := preload("res://scenes/screens/PuzzleScreen.gd")
const SettingsScreen := preload("res://scenes/screens/SettingsScreen.gd")
const ShopScreen := preload("res://scenes/screens/ShopScreen.gd")
const DebugMenu := preload("res://scenes/screens/DebugMenu.gd")

var screen: Control

var _idle_check_pending: bool = true


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = get_theme_color("bg", "Hardwire")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	show_boot()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_idle_check_pending = true
		if screen is OverviewScreen:
			check_idle()


func show_boot() -> void:
	var boot: Control = BootScreen.new()
	boot.start_requested.connect(show_overview)
	_show(boot)


func show_overview() -> void:
	var overview: Control = OverviewScreen.new()
	overview.play_requested.connect(show_puzzle)
	overview.settings_requested.connect(show_settings)
	overview.shop_requested.connect(show_shop)
	overview.rebuild_requested.connect(show_rebuild_dialog)
	overview.debug_requested.connect(show_debug)
	_show(overview)
	if _idle_check_pending:
		check_idle()


## Offers idle Cycles if enough time passed since the last save (SPEC: Idle income).
func check_idle() -> void:
	_idle_check_pending = false
	var amount: int = GameState.idle_offer(int(Time.get_unix_time_from_system()))
	if amount <= 0:
		return
	var dialog := ConfirmDialog.open(screen, "While you were away",
		"Your rig computed %d Cycles." % amount, "Collect", "")
	dialog.confirmed.connect(func() -> void:
		GameState.collect_idle(amount)
		SaveManager.save_game())


## Confirm dialog with Cores to gain and the new multiplier (SPEC: Prestige).
func show_rebuild_dialog() -> void:
	if not GameState.can_rebuild():
		return
	var gained: int = GameState.rebuild_cores()
	var message: String = "Gain %d %s: rewards x%s -> x%s.\nStats, Cycles, upgrades and first solves reset." % [
		gained, "Core" if gained == 1 else "Cores", Economy.core_multiplier(GameState.cores),
		Economy.core_multiplier(GameState.cores + gained)]
	var dialog := ConfirmDialog.open(screen, "Rebuild?", message, "Rebuild")
	dialog.confirmed.connect(func() -> void:
		GameState.rebuild()
		SaveManager.save_game()
		show_overview())


func show_puzzle(slot: SlotDef) -> void:
	var puzzle_screen: Control = PuzzleScreen.new()
	puzzle_screen.setup(slot)
	puzzle_screen.exit_requested.connect(show_overview)
	_show(puzzle_screen)


func show_settings() -> void:
	var settings: Control = SettingsScreen.new()
	settings.exit_requested.connect(show_overview)
	_show(settings)


func show_shop() -> void:
	var shop: Control = ShopScreen.new()
	shop.exit_requested.connect(show_overview)
	_show(shop)


func show_debug() -> void:
	var menu: Control = DebugMenu.new()
	menu.play_requested.connect(show_puzzle)
	menu.exit_requested.connect(show_overview)
	_show(menu)


## Android back (SPEC: Back button): back to the overview, or quit from the overview / boot screen.
## Ignored while a dialog is open.
func go_back() -> void:
	if screen == null or not screen.find_children("*", "ConfirmDialog", true, false).is_empty():
		return
	if screen is OverviewScreen or screen is BootScreen:
		SaveManager.save_game()
		get_tree().quit()
	elif screen is PuzzleScreen:
		screen.go_back()
	else:
		show_overview()


## Swaps the current screen; the new one fades in over the theme's transition_ms.
func _show(next: Control) -> void:
	if screen:
		screen.queue_free()
	screen = next
	add_child(screen)
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0,
		get_theme_constant("transition_ms", "Hardwire") / 1000.0)
