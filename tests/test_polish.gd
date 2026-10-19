extends "res://tests/hardwire_test.gd"
## M8 polish: first-run hints, screen transitions, Android back navigation.

const Main := preload("res://scenes/Main.tscn")
const PuzzleScreen := preload("res://scenes/screens/PuzzleScreen.gd")
const OverviewScreen := preload("res://scenes/screens/OverviewScreen.gd")
const SettingsScreen := preload("res://scenes/screens/SettingsScreen.gd")


func _release() -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.pressed = false
	touch.position = Vector2(500, 900)
	return touch


func test_first_run_hint_holds_attempt_until_tapped() -> void:
	GameState.seen_tutorials = [] as Array[String]
	var screen: Control = PuzzleScreen.new()
	screen.setup(SlotGenerator.make(1, SlotDef.TYPE_RAM))
	add_child_autofree(screen)
	assert_not_null(screen.hint)
	assert_eq(screen.hint.text, "Recreate the pattern")
	assert_eq(screen.puzzle.phase, PuzzleBase.Phase.IDLE, "waits for the tap")
	screen.hint._input(_release())
	assert_eq(screen.puzzle.phase, PuzzleBase.Phase.COUNTDOWN)
	assert_true(GameState.seen_tutorials.has(SlotDef.TYPE_RAM))
	assert_true(FileAccess.file_exists(TEST_SAVE), "saved")


func test_hint_shown_once() -> void:
	var screen: Control = PuzzleScreen.new()
	screen.setup(SlotGenerator.make(1, SlotDef.TYPE_CPU))
	add_child_autofree(screen)
	assert_null(screen.hint)
	assert_eq(screen.puzzle.phase, PuzzleBase.Phase.COUNTDOWN)


func _main() -> Node:
	var main: Node = Main.instantiate()
	main._idle_check_pending = false
	add_child_autofree(main)
	return main


func test_screens_fade_in() -> void:
	var main := _main()
	main.show_settings()
	assert_eq(main.screen.modulate.a, 0.0)
	await wait_seconds(0.3)
	assert_eq(main.screen.modulate.a, 1.0)


func test_back_returns_to_overview() -> void:
	var main := _main()
	main.show_shop()
	main.go_back()
	assert_true(main.screen is OverviewScreen)
	main.show_puzzle(SlotGenerator.make(1, SlotDef.TYPE_STO))
	main.go_back()
	assert_true(main.screen is OverviewScreen)


func test_back_ignored_while_dialog_open() -> void:
	var main := _main()
	main.show_settings()
	ConfirmDialog.open(main.screen, "t", "m", "ok")
	main.go_back()
	assert_true(main.screen is SettingsScreen)


func test_stat_bar_short_numbers() -> void:
	assert_eq(StatBar.short(9999), "9999")
	assert_eq(StatBar.short(12_345), "12.3K")
	assert_eq(StatBar.short(4_560_000), "4.56M")
