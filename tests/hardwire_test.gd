extends GutTest
## Base for tests that touch GameState or screens: snapshots and restores GameState, redirects
## saves to a test file and mutes sound, so the real save is never touched.
## Not collected itself (no test_ prefix); tests extend it by path.

const TEST_SAVE := "user://test_save.json"
const FRAME := 1.0 / 60.0

var _orig_path: String
var _orig_state: Dictionary
var _orig_time_scale: float
var _orig_device: int
var _orig_music: bool


func before_each() -> void:
	_orig_path = SaveManager.save_path
	_orig_state = SaveManager.to_dict()
	_orig_time_scale = Engine.time_scale
	_orig_device = InputMode.device
	_orig_music = Synth.is_music_enabled()
	SaveManager.save_path = TEST_SAVE
	_remove_test_files()
	GameState.reset_all()
	GameState.settings.sound = false
	GameState.settings.haptics = false
	# First-run hints hold the first attempt; tests that check hints clear this.
	GameState.seen_tutorials = SlotGenerator.TYPES.duplicate()


func after_each() -> void:
	_remove_test_files()
	SaveManager.save_path = _orig_path
	SaveManager.from_dict(_orig_state)
	Engine.time_scale = _orig_time_scale
	InputMode.device = _orig_device as InputMode.Device
	Synth.set_music_enabled(_orig_music)


func _remove_test_files() -> void:
	for path: String in [SaveManager.save_path, SaveManager.tmp_path(), SaveManager.backup_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Sets all three stats to `value`.
func set_stats(value: int) -> void:
	GameState.add_stats(value - GameState.ram, value - GameState.cpu, value - GameState.sto)


## Puts `node` into a new SubViewport of `size` (portrait or landscape) and returns the node.
## Screens see that viewport's size, so layouts can be tested at any resolution.
func in_viewport(node: Node, size: Vector2i) -> Node:
	var viewport := SubViewport.new()
	viewport.size = size
	add_child_autofree(viewport)
	viewport.add_child(node)
	return node


## Sends an InputEventAction (gamepad/keyboard equivalent) through `viewport`'s input path.
func press_action(viewport: Viewport, action: String, pressed: bool = true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	viewport.push_input(event)


func tap_action(viewport: Viewport, action: String) -> void:
	press_action(viewport, action, true)
	press_action(viewport, action, false)


## Sends a touch press and release at `position` (viewport coordinates) through `viewport`.
## `steps` [true] only presses (a finger held down), [false] only releases.
func tap_at(viewport: Viewport, position: Vector2, steps: Array[bool] = [true, false]) -> void:
	for pressed: bool in steps:
		var touch := InputEventScreenTouch.new()
		touch.position = position
		touch.pressed = pressed
		viewport.push_input(touch)


## Presses the left mouse button at `from`, moves by `delta` and releases. A finger on a
## touchscreen reaches scroll lists as exactly these emulated mouse events.
func drag(viewport: Viewport, from: Vector2, delta: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	viewport.push_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = from + delta
	motion.relative = delta
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = from + delta
	viewport.push_input(release)


## A started puzzle of `script` (StoragePuzzle, RamPuzzle or CpuPuzzle) in a phone-sized area.
## `touchable` puts it in its own SubViewport so touches can be pushed to it (tap_at).
func make_puzzle(
	script: Script, tier: int, modifier: String = "", seed: int = 7, touchable: bool = false
) -> PuzzleBase:
	var puzzle: PuzzleBase = script.new()
	puzzle.size = Vector2(1000, 1400)
	if touchable:
		in_viewport(puzzle, Vector2i(puzzle.size))
	else:
		add_child_autofree(puzzle)
	var type: String = {StoragePuzzle: "sto", RamPuzzle: "ram", CpuPuzzle: "cpu"}[script]
	puzzle.setup(SlotDef.create(tier, type, modifier), seed)
	puzzle.start()
	return puzzle


## Simulates frames (the puzzle and its scripted children) until `phase`, at most `max_s` seconds.
func run_until(puzzle: PuzzleBase, phase: PuzzleBase.Phase, max_s: float = 30.0) -> void:
	var t: float = 0.0
	while puzzle.phase != phase and t < max_s:
		run_for(puzzle, FRAME)
		t += FRAME


## Simulates `seconds` of frames.
func run_for(puzzle: PuzzleBase, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		puzzle._process(FRAME)
		for child: Node in puzzle.get_children():
			if child.has_method("_process"):
				child._process(FRAME)
		t += FRAME


## The Main scene; `offer_idle` false suppresses the "While you were away" dialog.
func make_main(offer_idle: bool = false) -> Node:
	var main: Node = preload("res://scenes/Main.tscn").instantiate()
	main.offer_idle = offer_idle
	add_child_autofree(main)
	return main
