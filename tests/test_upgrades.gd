# gdlint: disable=max-public-methods
extends "res://tests/hardwire_test.gd"
## Upgrade shop (SPEC: Upgrade shop): costs, buying, persistence and each upgrade's effect.

const StoragePuzzle := preload("res://scenes/puzzles/StoragePuzzle.gd")
const ShopScreen := preload("res://scenes/screens/ShopScreen.gd")


func _slot(tier: int, type: String, levels: Dictionary) -> SlotDef:
	var slot := SlotDef.create(tier, type)
	slot.assist = levels
	return slot


func test_buy_deducts_and_levels() -> void:
	GameState.cycles = 100
	assert_true(GameState.buy_upgrade("metronome"))
	assert_eq(GameState.cycles, 70)
	assert_eq(GameState.upgrade_level("metronome"), 1)
	assert_true(GameState.buy_upgrade("metronome"))
	assert_eq(GameState.cycles, 16)
	assert_false(GameState.buy_upgrade("metronome"), "97 is too expensive")
	assert_eq(GameState.cycles, 16)


func test_cannot_buy_past_max() -> void:
	GameState.cycles = 10_000
	assert_true(GameState.buy_upgrade("replay_buffer"))
	assert_true(GameState.buy_upgrade("replay_buffer"))
	assert_false(GameState.buy_upgrade("replay_buffer"))
	assert_eq(GameState.cycles, 10_000 - 200)


func test_upgrades_persist() -> void:
	GameState.cycles = 1000
	GameState.buy_upgrade("cycle_miner")
	GameState.buy_upgrade("longer_exposure")
	SaveManager.save_game()
	GameState.reset_all()
	SaveManager.load_game()
	assert_eq(GameState.upgrade_level("cycle_miner"), 1)
	assert_eq(GameState.upgrade_level("longer_exposure"), 1)
	assert_eq(GameState.cycles, 1000 - 80 - 30)


func test_longer_exposure_extends_ram_show_time() -> void:
	assert_eq(GridGen.make(_slot(1, SlotDef.TYPE_RAM, {"longer_exposure": 3}), 1).show_ms, 3250)
	assert_eq(
		GridGen.make(_slot(20, SlotDef.TYPE_RAM, {"longer_exposure": 5}), 1).show_ms,
		1500,
		"applies after the floor"
	)


func test_metronome_widens_cpu_tolerance() -> void:
	assert_almost_eq(
		RhythmGen.make(_slot(1, SlotDef.TYPE_CPU, {"metronome": 2}), 1).tolerance, 0.36, 0.0001
	)
	assert_almost_eq(
		RhythmGen.make(_slot(40, SlotDef.TYPE_CPU, {"metronome": 5}), 1).tolerance, 0.30, 0.0001
	)


func test_time_dilation_extends_all_limits() -> void:
	var td := {"time_dilation": 2}
	assert_almost_eq(
		SequenceGen.make(_slot(1, SlotDef.TYPE_STO, td), 1).time_limit_s, 4.5 * 1.3, 0.0001
	)
	assert_almost_eq(
		GridGen.make(_slot(1, SlotDef.TYPE_RAM, td), 1).time_limit_s, 6.4 * 1.3, 0.0001
	)
	assert_almost_eq(
		RhythmGen.make(_slot(1, SlotDef.TYPE_CPU, td), 1).first_press_timeout_s, 6.5, 0.0001
	)


func test_overclock_and_miner_boost_rewards() -> void:
	GameState.upgrades.overclock = 2
	GameState.upgrades.cycle_miner = 1
	# tier 5 replay: reward 6 x 1.2 = 7.2 -> 7; cycles 25 x 1.1 = 27.5 -> 28
	var slot: SlotDef = SlotGenerator.make(5, SlotDef.TYPE_RAM)
	GameState.solved_slots.append(slot.id())
	set_stats(32)
	var gain: Dictionary = GameState.apply_solve(slot)
	assert_eq([gain.stat, gain.cycles], [7, 28])


func test_puzzle_screen_copies_upgrade_levels() -> void:
	GameState.upgrades.time_dilation = 3
	var screen: Control = preload("res://scenes/screens/PuzzleScreen.gd").new()
	var slot: SlotDef = SlotGenerator.make(1, SlotDef.TYPE_STO)
	screen.setup(slot)
	assert_eq(slot.assist_level("time_dilation"), 3)
	screen.free()


func _storage(levels: Dictionary) -> PuzzleBase:
	var puzzle: PuzzleBase = StoragePuzzle.new()
	puzzle.size = Vector2(1000, 1400)
	add_child_autofree(puzzle)
	puzzle.setup(_slot(5, SlotDef.TYPE_STO, levels), 9)
	puzzle.start()
	while puzzle.phase != PuzzleBase.Phase.INPUT:
		puzzle._process(FRAME)
	return puzzle


func test_no_replay_without_upgrade() -> void:
	var puzzle := _storage({})
	assert_eq(puzzle.replays_left(), 0)
	assert_false(puzzle._replay_button.visible)
	puzzle.replay()
	assert_eq(puzzle.phase, PuzzleBase.Phase.INPUT)


func test_replay_buffer_replays_and_resets() -> void:
	var puzzle := _storage({"replay_buffer": 2})
	watch_signals(puzzle)
	assert_true(puzzle._replay_button.visible)
	puzzle.tap_pad(puzzle.expected()[0])
	for i: int in 30:
		puzzle._process(FRAME)
	puzzle.replay()
	assert_eq(puzzle.phase, PuzzleBase.Phase.WATCH)
	assert_eq(puzzle.progress(), 0)
	assert_eq(puzzle.replays_left(), 1)
	while puzzle.phase != PuzzleBase.Phase.INPUT:
		puzzle._process(FRAME)
	assert_almost_eq(
		puzzle.time_left_s, puzzle.time_limit_s, 0.0001, "timer restarts at full length"
	)
	puzzle.replay()
	assert_eq(puzzle.replays_left(), 0)
	while puzzle.phase != PuzzleBase.Phase.INPUT:
		puzzle._process(FRAME)
	assert_false(puzzle._replay_button.visible, "no uses left")
	for pad: int in puzzle.expected():
		puzzle.tap_pad(pad)
	assert_signal_emitted(puzzle, "solved")


func test_shop_buy_button() -> void:
	GameState.cycles = 60
	var shop: Control = ShopScreen.new()
	add_child_autofree(shop)
	await wait_process_frames(1)
	var cards: Array[UpgradeCard] = shop.cards
	assert_eq(cards.size(), 6)
	var by_id := {}
	for card: UpgradeCard in cards:
		by_id[card.id] = card
	assert_true(by_id.overclock._buy.disabled, "100 > 60")
	assert_false(by_id.metronome._buy.disabled)
	by_id.metronome._buy.pressed.emit()
	assert_eq(GameState.upgrade_level("metronome"), 1)
	assert_eq(GameState.cycles, 30)
	assert_true(FileAccess.file_exists(TEST_SAVE), "purchase saved")
	assert_true(by_id.metronome._buy.disabled, "54 > 30")
