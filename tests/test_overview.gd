# gdlint: disable=max-public-methods
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


## A tall overview in a phone-sized viewport, scrolled to the newest unlocked tier.
func _tall_overview() -> Control:
	set_stats(100_000)
	var overview: Control = in_viewport(OverviewScreen.new(), Vector2i(1080, 1920))
	await wait_process_frames(2)
	return overview


func _scroll_of(overview: Control) -> ScrollContainer:
	return overview.find_children("*", "ScrollContainer", true, false)[0]


func _newest_card(overview: Control) -> SlotCard:
	return overview.rows()[Progress.highest_unlocked_tier(GameState.stats()) - 1].cards[0]


func test_opens_scrolled_to_newest_tier() -> void:
	var overview: Control = await _tall_overview()
	var view: Rect2 = _scroll_of(overview).get_global_rect()
	var rows: Array[TierRow] = overview.rows()
	var newest: TierRow = rows[Progress.highest_unlocked_tier(GameState.stats()) - 1]
	assert_true(view.encloses(newest.get_global_rect()), "newest unlocked tier is in view")
	assert_false(view.intersects(rows[0].get_global_rect()), "tier 1 scrolled out of view")


## A swipe that starts on a slot card scrolls the list (touch arrives as emulated mouse events,
## which a Button would otherwise swallow) and does not open the card.
func test_swipe_over_cards_scrolls_the_list() -> void:
	var overview: Control = await _tall_overview()
	var scroll: ScrollContainer = _scroll_of(overview)
	var before: int = scroll.scroll_vertical
	watch_signals(overview)
	drag(
		overview.get_viewport(),
		_newest_card(overview).get_global_rect().get_center(),
		Vector2(0, 300)
	)
	assert_lt(scroll.scroll_vertical, before, "finger down moves the list down")
	assert_signal_not_emitted(overview, "play_requested")


## A tap with a little finger wobble is still a tap (scroll deadzone).
func test_tap_with_small_wobble_still_opens_card() -> void:
	var overview: Control = await _tall_overview()
	var scroll: ScrollContainer = _scroll_of(overview)
	var before: int = scroll.scroll_vertical
	watch_signals(overview)
	drag(
		overview.get_viewport(),
		_newest_card(overview).get_global_rect().get_center(),
		Vector2(0, 6)
	)
	assert_signal_emitted(overview, "play_requested")
	assert_eq(scroll.scroll_vertical, before, "list did not move")


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


## D-039: unmet requirement chips are amber, met ones dim.
func test_requirement_chips_colour() -> void:
	var overview := _overview()
	var theme: Theme = ThemeDB.get_project_theme()
	var chips: Array[Label] = overview.rows()[1]._chips
	assert_eq(chips[0].get_theme_color("font_color"), theme.get_color("warn", "Hardwire"))
	set_stats(2)
	overview._refresh_rows()
	assert_eq(chips[0].get_theme_color("font_color"), theme.get_color("text_dim", "Hardwire"))


## D-039: the header's status names the real state.
func test_hub_status_line() -> void:
	var overview := _overview()
	assert_eq(overview.status.text, "System ready")
	set_stats(162)
	GameState.apply_solve(SlotGenerator.make(10, SlotDef.TYPE_RAM))
	overview._refresh_rows()
	assert_eq(overview.status.text, "Rebuild available")
	assert_false(overview.rebuild_button.disabled)
	var landscape: Control = in_viewport(OverviewScreen.new(), Vector2i(1920, 1080))
	await wait_process_frames(2)
	var header: Control = landscape.status.get_parent()
	assert_lte(
		header.size.x,
		float(landscape.get_theme_constant("side_panel", "Hardwire")),
		"the status fits the sidebar (stacked under the name)"
	)


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
		bar._gui_input(touch)
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


func test_overview_has_quit_on_pc() -> void:
	var overview := _overview()
	assert_has(_button_texts(overview), "Quit", "tests run on PC (D-025)")
	var settings := SettingsScreen.new()
	add_child_autofree(settings)
	assert_does_not_have(_button_texts(settings), "Quit", "Quit left Settings")


func test_ambient_score_only_runs_on_gameplay_screens() -> void:
	var main: Control = load("res://scenes/Main.gd").new()
	add_child_autofree(main)
	main.show_boot()
	assert_false(Synth.is_music_enabled())
	main.show_overview()
	assert_true(Synth.is_music_enabled())
	main.show_settings()
	assert_false(Synth.is_music_enabled())
	main.show_puzzle(SlotGenerator.make(1, SlotDef.TYPE_STO))
	assert_true(Synth.is_music_enabled())


func _button_texts(screen: Control) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in screen.find_children("*", "Button", true, false):
		texts.append((node as Button).text)
	return texts
