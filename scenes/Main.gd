extends Control
## Root scene. Holds the current screen and handles transitions (SPEC: Screens and UX flow).
## Until the overview exists (M5) the entry screen is the debug menu.

const DebugMenu := preload("res://scenes/screens/DebugMenu.gd")
const PuzzleScreen := preload("res://scenes/screens/PuzzleScreen.gd")

var screen: Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = get_theme_color("bg", "Hardwire")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	show_debug_menu()


func show_debug_menu() -> void:
	var menu: Control = DebugMenu.new()
	menu.play_requested.connect(show_puzzle)
	_show(menu)


func show_puzzle(slot: SlotDef) -> void:
	var puzzle_screen: Control = PuzzleScreen.new()
	puzzle_screen.setup(slot)
	puzzle_screen.exit_requested.connect(show_debug_menu)
	_show(puzzle_screen)


func _show(next: Control) -> void:
	if screen:
		screen.queue_free()
	screen = next
	add_child(screen)
