extends Control
## Root scene. Holds the current screen and handles transitions (SPEC: Screens and UX flow):
## Boot -> Overview hub -> Puzzle / Settings / debug panel (and Shop, Rebuild later).

const BootScreen := preload("res://scenes/screens/BootScreen.gd")
const OverviewScreen := preload("res://scenes/screens/OverviewScreen.gd")
const PuzzleScreen := preload("res://scenes/screens/PuzzleScreen.gd")
const SettingsScreen := preload("res://scenes/screens/SettingsScreen.gd")
const DebugMenu := preload("res://scenes/screens/DebugMenu.gd")

var screen: Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = get_theme_color("bg", "Hardwire")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	show_boot()


func show_boot() -> void:
	var boot: Control = BootScreen.new()
	boot.start_requested.connect(show_overview)
	_show(boot)


func show_overview() -> void:
	var overview: Control = OverviewScreen.new()
	overview.play_requested.connect(show_puzzle)
	overview.settings_requested.connect(show_settings)
	overview.debug_requested.connect(show_debug)
	_show(overview)


func show_puzzle(slot: SlotDef) -> void:
	var puzzle_screen: Control = PuzzleScreen.new()
	puzzle_screen.setup(slot)
	puzzle_screen.exit_requested.connect(show_overview)
	_show(puzzle_screen)


func show_settings() -> void:
	var settings: Control = SettingsScreen.new()
	settings.exit_requested.connect(show_overview)
	_show(settings)


func show_debug() -> void:
	var menu: Control = DebugMenu.new()
	menu.play_requested.connect(show_puzzle)
	menu.exit_requested.connect(show_overview)
	_show(menu)


func _show(next: Control) -> void:
	if screen:
		screen.queue_free()
	screen = next
	add_child(screen)
