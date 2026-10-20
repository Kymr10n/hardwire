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
	var style := card.get_theme_stylebox("normal") as BevelBox
	assert_eq(style.bg, card.get_theme_color("card", "Hardwire"))
	assert_eq(style.light, card.get_theme_color("ram", "Hardwire"), "new slot: accent border")
	assert_true(card.badge_new.visible, "new slot: NEW sticker")


func test_overview_has_quit_on_pc() -> void:
	var overview := _overview()
	assert_has(_button_texts(overview), "QUIT", "tests run on PC (D-025)")
	var settings := SettingsScreen.new()
	add_child_autofree(settings)
	assert_does_not_have(_button_texts(settings), "QUIT", "Quit left Settings")


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


func _led_banks(overview: Control) -> Array[Deco]:
	var banks: Array[Deco] = []
	for node: Node in overview.find_children("*", "Deco", true, false):
		if (node as Deco).kind == Deco.Kind.LED_BANK:
			banks.append(node)
	return banks


func test_stat_bar_leds_show_progress_to_next_tier() -> void:
	var overview := _overview()
	var banks: Array[Deco] = _led_banks(overview)
	assert_eq(banks.size(), 3, "one bank per stat")
	assert_eq(banks[0].lit, 0)
	GameState.add_stats(1, 0, 0)
	assert_eq(banks[0].lit, 5, "RAM 1 of the 2 tier 2 needs")
	GameState.add_stats(1, 0, 0)
	assert_eq(banks[0].lit, 10)


func test_cycles_readout_pulses_on_change() -> void:
	var overview := _overview()
	GameState.add_cycles(1234)
	var readout: Label = _label(overview, "1234")
	var idle: Color = overview.get_theme_color("led_amber", "Hardwire")
	await wait_seconds(0.3)
	assert_eq(readout.get_theme_color("font_color"), idle)
	GameState.add_cycles(5)
	assert_ne(readout.get_theme_color("font_color"), idle, "flashes bright")
	await wait_seconds(0.3)
	assert_eq(readout.get_theme_color("font_color"), idle, "back to amber within tap_flash_ms")


func test_slot_cards_are_bays_with_stamps() -> void:
	var overview := _overview()
	var open: SlotCard = overview.rows()[0].cards[1]
	var locked: SlotCard = overview.rows()[2].cards[1]
	assert_true(_has_text(open, "BAY 2"), "tier 1, second bay")
	assert_true(_has_text(locked, "BAY 8"), "tier 3, second bay")
	assert_false(_stamp(open).visible, "an open bay has no EMPTY BAY stamp")
	assert_true(_stamp(locked).visible, "a locked bay is stamped EMPTY BAY")
	assert_true(_has_text(overview, Ui.FINE_PRINT), "fine-print footer")


func test_only_the_rebuild_dialog_has_the_hazard_frame() -> void:
	var overview := _overview()
	overview._confirm_rebuild()
	var dialog: ConfirmDialog = overview.find_children("*", "ConfirmDialog", true, false)[0]
	assert_true(dialog.hazard)
	var panel: PanelContainer = dialog.find_children("*", "PanelContainer", true, false)[0]
	assert_true(panel.get_theme_stylebox("panel").get("hazard"), "striped frame")
	var plain := ConfirmDialog.open(overview, "Reset save?", "", "Erase")
	var plain_panel: PanelContainer = plain.find_children("*", "PanelContainer", true, false)[0]
	assert_false(plain_panel.get_theme_stylebox("panel").get("hazard"))


func _has_text(node: Node, text: String) -> bool:
	return _label(node, text) != null


func _label(node: Node, text: String) -> Label:
	for label: Node in node.find_children("*", "Label", true, false):
		if (label as Label).text == text:
			return label
	return null


func _stamp(card: SlotCard) -> Label:
	return _label(card, "EMPTY BAY")
