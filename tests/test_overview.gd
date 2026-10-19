extends "res://tests/hardwire_test.gd"
## Overview screen: visible tiers, card states, gating in the UI, reward flow from the puzzle
## screen.


func _overview() -> Control:
	var overview: Control = OverviewScreen.new()
	add_child_autofree(overview)
	return overview


func test_shows_unlocked_plus_two_locked_tiers() -> void:
	var overview := _overview()
	assert_eq(overview.rows().size(), 3)
	set_stats(32)
	assert_eq(overview.rows().size(), 7, "tiers 1-5 unlocked + 2 locked")


func test_card_states() -> void:
	var overview := _overview()
	var t1: SlotCard = overview.rows()[0].cards[0]
	var t2: SlotCard = overview.rows()[1].cards[0]
	assert_false(t1.disabled, "tier 1 is open")
	assert_true(t2.disabled, "tier 2 is locked")
	assert_eq(Progress.missing(t2.slot.req, GameState.stats()), {"ram": 2, "cpu": 2, "sto": 2})
	GameState.apply_solve(t1.slot)
	overview._refresh_rows()
	assert_true(GameState.is_solved(t1.slot))


func test_rebuild_disabled_before_tier_10() -> void:
	var overview := _overview()
	assert_true(overview.rebuild_button.disabled)


func test_card_press_requests_play() -> void:
	var overview := _overview()
	watch_signals(overview)
	overview.rows()[0].cards[1].pressed.emit()
	assert_signal_emitted(overview, "play_requested")
	var slot: SlotDef = get_signal_parameters(overview, "play_requested")[0]
	assert_eq(slot.id(), "1:cpu")


func test_puzzle_solve_credits_and_saves() -> void:
	var screen: Control = PuzzleScreen.new()
	screen.setup(SlotGenerator.make(1, SlotDef.TYPE_STO))
	add_child_autofree(screen)
	await wait_process_frames(1)
	var puzzle: PuzzleBase = screen.puzzle
	run_until(puzzle, PuzzleBase.Phase.INPUT)
	for pad: int in puzzle.expected():
		puzzle.tap_pad(pad)
	assert_eq(GameState.sto, 4)
	assert_eq(GameState.cycles, 10)
	assert_true(FileAccess.file_exists(TEST_SAVE), "saved after the solve")
	assert_true(screen.overlay.visible)


func test_five_taps_on_stat_bar_open_debug_panel() -> void:
	var overview := _overview()
	await wait_process_frames(2)
	watch_signals(overview)
	var bar: StatBar = overview.find_children("*", "StatBar", true, false)[0]
	for i: int in 5:
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = bar.get_global_rect().get_center()
		bar._input(touch)
	assert_signal_emitted(overview, "debug_requested")


func test_slot_cards_draw_their_frame() -> void:
	var overview := _overview()
	var card: SlotCard = overview.rows()[0].cards[0]
	assert_false(card.flat, "a flat button would skip the card frame")
	var style := card.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(style.bg_color, card.get_theme_color("card", "Hardwire"))
	assert_eq(
		style.border_color, card.get_theme_color("ram", "Hardwire"), "new slot: accent border"
	)
