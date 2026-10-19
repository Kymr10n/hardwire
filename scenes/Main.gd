extends Control
## Root scene. Holds the current screen and handles transitions (SPEC: Screens and UX flow): Boot ->
## Overview hub -> Puzzle / Shop / Settings / debug panel, plus the Rebuild dialog and the "While
## you were away" idle income dialog (on start and after a resume, shown on the overview). Picks
## portrait or landscape from the window aspect and rebuilds the screen when it flips.

const BootScreen := preload("res://scenes/screens/BootScreen.gd")
const OverviewScreen := preload("res://scenes/screens/OverviewScreen.gd")
const PuzzleScreen := preload("res://scenes/screens/PuzzleScreen.gd")
const SettingsScreen := preload("res://scenes/screens/SettingsScreen.gd")
const ShopScreen := preload("res://scenes/screens/ShopScreen.gd")
const LicensesScreen := preload("res://scenes/screens/LicensesScreen.gd")
const DebugMenu := preload("res://scenes/screens/DebugMenu.gd")

var screen: Control

var _idle_check_pending: bool = true
var _landscape: bool = false
## Re-creates the current screen (used when the orientation flips).
var _rebuild: Callable


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = get_theme_color("bg", "Hardwire")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_apply_orientation()
	get_window().size_changed.connect(_on_window_resized)
	if wants_fullscreen(OS.get_environment("SteamDeck")):
		get_window().mode = Window.MODE_FULLSCREEN
	show_boot()


## Steam sets SteamDeck=1 on the Deck: start fullscreen there (SPEC: Controls).
static func wants_fullscreen(steam_deck_env: String) -> bool:
	return steam_deck_env == "1"


## Base size for the current window aspect: the project's portrait size, or the same size swapped.
static func base_size(window_size: Vector2i) -> Vector2i:
	var portrait := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	return Vector2i(portrait.y, portrait.x) if window_size.x > window_size.y else portrait


func _apply_orientation() -> void:
	var window := get_window()
	window.content_scale_size = base_size(window.size)
	_landscape = window.size.x > window.size.y


func _on_window_resized() -> void:
	var was_landscape: bool = _landscape
	_apply_orientation()
	if _landscape != was_landscape and _rebuild.is_valid():
		_rebuild.call()


## B / Esc goes back, unless something on the screen handled it first.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


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
	_show(boot, show_boot)


func show_overview() -> void:
	var overview: Control = OverviewScreen.new()
	overview.play_requested.connect(show_puzzle)
	overview.settings_requested.connect(show_settings)
	overview.shop_requested.connect(show_shop)
	overview.rebuild_requested.connect(show_rebuild_dialog)
	overview.debug_requested.connect(show_debug)
	_show(overview, show_overview)
	if _idle_check_pending:
		check_idle()


## Offers idle Cycles if enough time passed since the last save (SPEC: Idle income).
func check_idle() -> void:
	_idle_check_pending = false
	var amount: int = Progress.idle_offer(
		GameState.last_seen,
		int(Time.get_unix_time_from_system()),
		GameState.solved_slots,
		GameState.upgrade_level("cycle_miner"),
		GameState.cores
	)
	if amount <= 0:
		return
	var dialog := ConfirmDialog.open(
		screen, "While you were away", "Your rig computed %d Cycles." % amount, "Collect", ""
	)
	dialog.confirmed.connect(
		func() -> void:
			GameState.collect_idle(amount)
			SaveManager.save_game()
	)


## Confirm dialog with Cores to gain and the new multiplier (SPEC: Prestige).
func show_rebuild_dialog() -> void:
	if not Progress.can_rebuild(GameState.solved_slots):
		return
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
	var dialog := ConfirmDialog.open(screen, "Rebuild?", message, "Rebuild")
	dialog.confirmed.connect(
		func() -> void:
			GameState.rebuild()
			SaveManager.save_game()
			show_overview()
	)


func show_puzzle(slot: SlotDef) -> void:
	var puzzle_screen: Control = PuzzleScreen.new()
	puzzle_screen.setup(slot)
	puzzle_screen.exit_requested.connect(show_overview)
	_show(puzzle_screen, show_puzzle.bind(slot))


func show_settings() -> void:
	var settings: Control = SettingsScreen.new()
	settings.exit_requested.connect(show_overview)
	settings.licenses_requested.connect(show_licenses)
	_show(settings, show_settings)


func show_licenses() -> void:
	var licenses: Control = LicensesScreen.new()
	licenses.exit_requested.connect(show_settings)
	_show(licenses, show_licenses)


func show_shop() -> void:
	var shop: Control = ShopScreen.new()
	shop.exit_requested.connect(show_overview)
	_show(shop, show_shop)


func show_debug() -> void:
	var menu: Control = DebugMenu.new()
	menu.play_requested.connect(show_puzzle)
	menu.exit_requested.connect(show_overview)
	_show(menu, show_debug)


## Back (Android back, B, Esc; SPEC: Back button): back to the overview. From the overview or boot
## screen it quits on phones only; on PC, Settings has Quit. Ignored while a dialog is open.
func go_back() -> void:
	if screen == null or not screen.find_children("*", "ConfirmDialog", true, false).is_empty():
		return
	if screen is OverviewScreen or screen is BootScreen:
		if OS.has_feature("mobile"):
			SaveManager.save_game()
			get_tree().quit()
	elif screen is PuzzleScreen:
		screen.go_back()
	else:
		show_overview()


## Swaps the current screen; the new one fades in over the theme's transition_ms.
## `rebuild` re-creates it if the orientation flips.
func _show(next: Control, rebuild: Callable) -> void:
	if screen:
		screen.queue_free()
	screen = next
	_rebuild = rebuild
	add_child(screen)
	Ui.focus_first(screen)
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(
		screen, "modulate:a", 1.0, get_theme_constant("transition_ms", "Hardwire") / 1000.0
	)
