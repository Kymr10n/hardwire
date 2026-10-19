# gdlint: disable=max-public-methods
extends "res://tests/hardwire_test.gd"
## M8 polish: first-run hints, screen transitions, Android back navigation.

const MainScript := preload("res://scenes/Main.gd")


func test_first_run_hint_holds_attempt_until_tapped() -> void:
	GameState.seen_tutorials = [] as Array[String]
	var screen: Control = PuzzleScreen.new()
	screen.setup(SlotGenerator.make(1, SlotDef.TYPE_RAM))
	in_viewport(screen, Vector2i(1080, 1920))
	await wait_process_frames(2)
	assert_not_null(screen.hint)
	assert_eq(screen.hint.text, "Recreate the pattern")
	assert_eq(screen.puzzle.phase, PuzzleBase.Phase.IDLE, "waits for the tap")
	tap_at(screen.get_viewport(), screen.get_global_rect().get_center())
	assert_eq(screen.puzzle.phase, PuzzleBase.Phase.COUNTDOWN)
	assert_true(GameState.seen_tutorials.has(SlotDef.TYPE_RAM))
	assert_true(FileAccess.file_exists(TEST_SAVE), "saved")


func test_hint_shown_once() -> void:
	var screen: Control = PuzzleScreen.new()
	screen.setup(SlotGenerator.make(1, SlotDef.TYPE_CPU))
	add_child_autofree(screen)
	assert_null(screen.hint)
	assert_eq(screen.puzzle.phase, PuzzleBase.Phase.COUNTDOWN)


func test_screens_fade_in() -> void:
	var main := make_main()
	main.show_settings()
	assert_eq(main.screen.modulate.a, 0.0)
	await wait_seconds(0.3)
	assert_eq(main.screen.modulate.a, 1.0)


func test_back_returns_to_overview() -> void:
	var main := make_main()
	main.show_shop()
	main.go_back()
	assert_true(main.screen is OverviewScreen)
	main.show_puzzle(SlotGenerator.make(1, SlotDef.TYPE_STO))
	main.go_back()
	assert_true(main.screen is OverviewScreen)


func test_back_ignored_while_dialog_open() -> void:
	var main := make_main()
	main.show_settings()
	ConfirmDialog.open(main.screen, "t", "m", "ok")
	main.go_back()
	assert_true(main.screen is SettingsScreen)


func test_stat_bar_short_numbers() -> void:
	assert_eq(StatBar.short(9999), "9999")
	assert_eq(StatBar.short(12_345), "12.3K")
	assert_eq(StatBar.short(4_560_000), "4.56M")


func test_licenses_screen_shows_all_texts() -> void:
	var text: String = LicensesScreen.full_text()
	assert_string_contains(text, "Copyright (c) 2026 kamyrion")
	assert_string_contains(text, "SIL OPEN FONT LICENSE")
	assert_string_contains(text, "Godot Engine contributors")
	assert_string_contains(text, "FreeType")


func test_settings_opens_licenses_and_back_returns() -> void:
	var main := make_main()
	main.show_settings()
	main.screen.licenses_requested.emit()
	assert_true(main.screen is LicensesScreen)
	main.go_back()
	assert_true(main.screen is SettingsScreen, "Back from Licenses returns to Settings (D-023)")
	main.go_back()
	assert_true(main.screen is OverviewScreen)


func test_license_reflow_joins_wrapped_lines() -> void:
	assert_eq(LicensesScreen.reflow("a b\nc d\n\ne\n  - f\n  - g"), "a b c d\n\ne\n  - f\n  - g")


func test_base_size_follows_window_aspect() -> void:
	assert_eq(MainScript.base_size(Vector2i(1280, 800)), Vector2i(1920, 1080))
	assert_eq(MainScript.base_size(Vector2i(540, 960)), Vector2i(1080, 1920))
	assert_eq(
		MainScript.base_size(Vector2i(800, 800)), Vector2i(1080, 1920), "square counts as portrait"
	)


func test_fullscreen_only_on_steam_deck() -> void:
	assert_true(MainScript.wants_fullscreen("1"))
	assert_false(MainScript.wants_fullscreen(""))


func test_back_never_quits_on_pc_overview() -> void:
	var main := make_main()
	main.show_overview()
	main.go_back()
	assert_true(main.screen is OverviewScreen, "still on the overview (tests run on PC)")
	assert_false(get_tree().root.is_queued_for_deletion())


func test_theme_motion_constants_match_spec() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	assert_eq(theme.get_constant("glow_ms", "Hardwire"), 80)
	assert_eq(theme.get_constant("glow_scale_pct", "Hardwire"), 105)
	assert_eq(theme.get_constant("transition_ms", "Hardwire"), 150)


func test_modifier_display_names() -> void:
	assert_eq(SlotDef.modifier_name("audio_only"), "Audio only")
	assert_eq(SlotDef.modifier_name("reverse"), "Reverse")
	for type: String in SlotGenerator.TYPES:
		for modifier: Variant in Balance.section("modifiers").pools[type]:
			assert_true(SlotDef.MODIFIER_NAMES.has(modifier), "%s has a display name" % modifier)
	var screen: Control = PuzzleScreen.new()
	screen.setup(SlotDef.create(8, SlotDef.TYPE_CPU, "audio_only"))
	assert_eq(screen.title_text(), "CPU  T8  [Audio only]")
	screen.free()


func test_modifier_hint_lines() -> void:
	var ram: PuzzleBase = RamPuzzle.new()
	add_child_autofree(ram)
	ram.setup(SlotDef.create(8, SlotDef.TYPE_RAM, GridGen.MOD_INVERTED), 1)
	ram.start()
	assert_eq(ram.hint.text, "Set the dark cells")
	ram.setup(SlotDef.create(8, SlotDef.TYPE_RAM), 1)
	ram.start()
	assert_eq(ram.hint.text, "", "no hint without a modifier")
	var cpu: PuzzleBase = CpuPuzzle.new()
	add_child_autofree(cpu)
	cpu.setup(SlotDef.create(8, SlotDef.TYPE_CPU, RhythmGen.MOD_SYNCOPATED), 1)
	cpu.start()
	assert_eq(cpu.hint.text, "Half steps")


func test_countdown_counts_3_2_1_over_1_5_s() -> void:
	var puzzle := make_puzzle(StoragePuzzle, 1)
	var texts: Array[String] = []
	puzzle.phase_changed.connect(
		func(_phase: PuzzleBase.Phase, text: String) -> void: texts.append(text)
	)
	run_until(puzzle, PuzzleBase.Phase.WATCH)
	assert_eq(texts, ["2", "1", "Watch"] as Array[String], "3 was shown at start, then 2, 1")
	var started := make_puzzle(StoragePuzzle, 1)
	var t: float = 0.0
	while started.phase == PuzzleBase.Phase.COUNTDOWN:
		started._process(FRAME)
		t += FRAME
	assert_almost_eq(t, 1.5, 2 * FRAME)


func test_result_overlay_counts_up_and_notes_new_tier() -> void:
	var overlay := ResultOverlay.new()
	add_child_autofree(overlay)
	overlay.show_result(
		"Write complete",
		Color.WHITE,
		"STO",
		{"stat": 4, "cycles": 10, "first_solve": true, "new_tier": 2}
	)
	assert_eq(overlay.gain.text, "+0 STO    +0 Cycles", "count-up starts at 0")
	await wait_seconds(0.7)
	assert_eq(overlay.gain.text, "+4 STO    +10 Cycles", "full after 0.6 s")
	assert_string_contains(overlay.note.text, "First solve x2")
	assert_string_contains(overlay.note.text, "Tier 2 unlocked")


func test_slot_card_texts() -> void:
	GameState.add_stats(8, 4, 8)
	var locked := SlotCard.new()
	locked.setup(SlotGenerator.make(3, SlotDef.TYPE_RAM))
	add_child_autofree(locked)
	assert_eq(locked.lines.text, "CPU 4 more")
	assert_false(locked.badge_new.visible)
	var open := SlotCard.new()
	open.setup(SlotGenerator.make(1, SlotDef.TYPE_CPU))
	add_child_autofree(open)
	assert_eq(open.lines.text, "+4 CPU\n+10 Cyc", "first solve pays double")
	assert_true(open.badge_new.visible)
	var modifier := SlotCard.new()
	modifier.setup(SlotDef.create(8, SlotDef.TYPE_CPU, "audio_only"))
	add_child_autofree(modifier)
	assert_eq(modifier.modifier_label.text, "Audio only")


func test_idle_offer_after_resume() -> void:
	GameState.apply_solve(SlotGenerator.make(1, SlotDef.TYPE_RAM))
	GameState.last_seen = int(Time.get_unix_time_from_system()) - 2 * 3600
	var main := make_main()
	main.show_overview()
	assert_eq(main.screen.find_children("*", "ConfirmDialog", true, false).size(), 0)
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(main.screen.find_children("*", "ConfirmDialog", true, false).size(), 1)


func test_settings_change_is_saved() -> void:
	var settings := SettingsScreen.new()
	add_child_autofree(settings)
	for node: Node in settings.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("Sound"):
			(node as Button).pressed.emit()
	assert_true(GameState.settings.sound, "muted by the test base, toggled back on")
	assert_true(FileAccess.file_exists(TEST_SAVE))


func test_synth_tone_handle_is_zero_when_sound_is_off() -> void:
	GameState.settings.sound = false
	assert_eq(Synth.start_tone(), 0)
	GameState.settings.sound = true
	var id: int = Synth.start_tone()
	assert_gt(id, 0)
	Synth.stop_tone(id)
