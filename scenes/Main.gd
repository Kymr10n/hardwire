extends Control
## Root scene. Holds the current screen and handles transitions (SPEC: Screens and UX flow): Boot ->
## Overview hub -> Puzzle / Shop / Settings / debug panel, plus the "While you were away" idle
## income dialog (on start and after a resume, shown on the overview). Picks
## portrait or landscape from the window aspect and rebuilds the screen when it flips. The glass
## overlay (D-041) sits on its own canvas layer above every screen and dialog.

const GLASS_SHADER := preload("res://theme/glass.gdshader")

var screen: Control
## An idle-income offer is still due (on start and after a resume) and is made on the overview.
var offer_idle: bool = true

var _glass: ShaderMaterial
var _landscape: bool = false
## Re-creates the current screen (used when the orientation flips).
var _recreate_screen: Callable


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = get_theme_color("bg", "Hardwire")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_add_glass()
	_apply_orientation()
	get_window().size_changed.connect(_on_window_resized)
	# Steam sets SteamDeck=1 on the Deck: start fullscreen there (SPEC: Controls).
	if OS.get_environment("SteamDeck") == "1":
		get_window().mode = Window.MODE_FULLSCREEN
	show_boot()


## Full-screen glass shader above everything; its numbers come from the theme (one home).
func _add_glass() -> void:
	var layer := CanvasLayer.new()
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glass = ShaderMaterial.new()
	_glass.shader = GLASS_SHADER
	for effect: String in ["vignette", "scanline", "bloom", "flicker"]:
		_glass.set_shader_parameter(effect, Ui.pct(self, "glass_%s_pct" % effect))
	_glass.set_shader_parameter("scanline_px", get_theme_constant("glass_scanline_px", "Hardwire"))
	_glass.set_shader_parameter(
		"flicker_hz", 1000.0 / get_theme_constant("glass_flicker_period_ms", "Hardwire")
	)
	rect.material = _glass
	rect.resized.connect(func() -> void: _glass.set_shader_parameter("content_size", rect.size))
	layer.add_child(rect)
	add_child(layer)
	GameState.settings_changed.connect(_apply_glass)
	_apply_glass()


## The "CRT glass" setting keeps the vignette and turns the rest off.
func _apply_glass() -> void:
	_glass.set_shader_parameter("glass", 1.0 if GameState.settings.get("crt", true) else 0.0)


## Glass strength the shader is using (1 on, 0 off); for tests.
func glass_level() -> float:
	return _glass.get_shader_parameter("glass")


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
	if _landscape != was_landscape and _recreate_screen.is_valid():
		_recreate_screen.call()


## B / Esc / Backspace goes back, unless something on the screen handled it first;
## F1 / gamepad View opens the debug panel in debug builds.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()
	elif event.is_action_pressed("debug_panel") and OS.is_debug_build():
		get_viewport().set_input_as_handled()
		show_debug()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		offer_idle = true
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
	overview.debug_requested.connect(show_debug)
	_show(overview, show_overview)
	if offer_idle:
		check_idle()


## Offers idle Cycles if enough time passed since the last save (SPEC: Idle income). The offer
## stays due until it is collected, so a re-created screen cannot lose it.
func check_idle() -> void:
	var amount: int = Progress.idle_offer(
		GameState.last_seen,
		int(Time.get_unix_time_from_system()),
		GameState.solved_slots,
		GameState.upgrade_level("cycle_miner"),
		GameState.cores
	)
	if amount <= 0:
		offer_idle = false
		return
	var dialog := ConfirmDialog.open(
		screen, "While you were away", "Your rig computed %d Cycles." % amount, "Collect", ""
	)
	dialog.confirmed.connect(
		func() -> void:
			offer_idle = false
			GameState.add_cycles(amount)
			SaveManager.save_game()
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
	elif screen is LicensesScreen:
		show_settings()
	else:
		show_overview()


## Swaps the current screen; the new one fades in over the theme's transition_ms.
## `recreate` re-creates it if the orientation flips.
func _show(next: Control, recreate: Callable) -> void:
	if screen:
		screen.queue_free()
	screen = next
	Synth.set_music_enabled(next is OverviewScreen or next is PuzzleScreen)
	_recreate_screen = recreate
	add_child(screen)
	Ui.focus_first(screen)
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(
		screen, "modulate:a", 1.0, get_theme_constant("transition_ms", "Hardwire") / 1000.0
	)
