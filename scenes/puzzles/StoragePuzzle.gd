extends PuzzleBase
## Storage minigame: repeat the color sequence. SPEC: Minigame: Storage.
## Pads sit in a ring; each lights for show_ms with its tone, then a gap_ms pause.
## A wrong pad or the timeout fails the attempt; the last correct pad solves it.
## With the Replay buffer upgrade a Replay button replays the sequence (progress and timer reset).

var _attempt: Dictionary = {}
var _pads: Array[StoragePad] = []
var _pos: int = 0
var _lit_item: int = -1
var _replays_left: int = 0
var _replay_button: Button


func _ready() -> void:
	_replay_button = Button.new()
	_replay_button.pressed.connect(replay)
	_replay_button.hide()
	add_child(_replay_button)
	resized.connect(_layout)


func replays_left() -> int:
	return _replays_left


## Plays the sequence again during the input phase (Replay buffer); entered progress resets
## and the timer restarts when input resumes. Public for tests.
func replay() -> void:
	if phase != Phase.INPUT or _replays_left <= 0:
		return
	_replays_left -= 1
	_pos = 0
	_lit_item = -1
	for pad: StoragePad in _pads:
		pad.set_level(0.0)
	_set_phase(Phase.WATCH, "Watch")


## Number of correct pads entered so far in this attempt.
func progress() -> int:
	return _pos


func expected() -> Array[int]:
	return _attempt.get("expected", [] as Array[int])


func pads() -> Array[StoragePad]:
	return _pads


## Handles one pad tap during the input phase (called from _input; public for tests).
func tap_pad(index: int) -> void:
	if phase != Phase.INPUT or index < 0 or index >= _pads.size():
		return
	_pads[index].flash()
	Synth.play_note(index, get_theme_constant("tap_flash_ms", "Hardwire"))
	Haptics.pulse()
	var target: Array[int] = expected()
	if index != target[_pos]:
		_fail()
		return
	_pos += 1
	if _pos == target.size():
		_succeed({"slot_id": slot.id()})


func _input(event: InputEvent) -> void:
	if phase != Phase.INPUT:
		return
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	for pad: StoragePad in _pads:
		if pad.get_global_rect().has_point(touch.position):
			get_viewport().set_input_as_handled()
			tap_pad(pad.index)
			return


func _build_attempt() -> void:
	_attempt = SequenceGen.make(slot, attempt_seed)
	time_limit_s = _attempt.time_limit_s
	_pos = 0
	_lit_item = -1
	_replays_left = _attempt.replays
	_ensure_pads(_attempt.pads)
	for pad: StoragePad in _pads:
		pad.set_level(0.0)


func _watch_update(t: float) -> bool:
	var show_s: float = _attempt.show_ms / 1000.0
	var item_s: float = show_s + _attempt.gap_ms / 1000.0
	var playback: Array[Dictionary] = _attempt.playback
	var item: int = floori(t / item_s)
	if item >= playback.size():
		_light_item(-1)
		return true
	_light_item(item if t - item * item_s < show_s else -1)
	return false


func _light_item(item: int) -> void:
	if item == _lit_item:
		return
	_lit_item = item
	for pad: StoragePad in _pads:
		pad.set_level(0.0)
	if item < 0:
		return
	var entry: Dictionary = _attempt.playback[item]
	if entry.decoy:
		_pads[entry.pad].set_level(get_theme_constant("decoy_pct", "Hardwire") / 100.0)
		Synth.play_note(entry.pad, _attempt.show_ms, Balance.get_num("audio", "decoy_volume"))
	else:
		_pads[entry.pad].set_level(1.0)
		Synth.play_note(entry.pad, _attempt.show_ms)


func _on_phase_entered(p_phase: Phase) -> void:
	_replay_button.visible = p_phase == Phase.INPUT and _replays_left > 0
	_replay_button.text = "Replay (%d)" % _replays_left


func _on_fail_reveal() -> void:
	var target: Array[int] = expected()
	if _pos < target.size():
		_pads[target[_pos]].set_level(1.0)


func _on_abort() -> void:
	for pad: StoragePad in _pads:
		pad.set_level(0.0)


func _ensure_pads(count: int) -> void:
	if _pads.size() == count:
		return
	for pad: StoragePad in _pads:
		pad.queue_free()
	_pads.clear()
	for i: int in count:
		var pad := StoragePad.new(i)
		add_child(pad)
		_pads.append(pad)
	_layout()


## Ring around the center, first pad at the top, clockwise.
func _layout() -> void:
	if _replay_button:
		var tap: float = get_theme_constant("tap_min", "Hardwire")
		_replay_button.size = Vector2(tap * 3.0, tap)
		_replay_button.position = Vector2((size.x - _replay_button.size.x) / 2.0, size.y - tap)
	if _pads.is_empty():
		return
	var pad_size: float = get_theme_constant("pad_size", "Hardwire")
	var center: Vector2 = size / 2.0
	var radius: float = maxf(0.0, minf(size.x, size.y) / 2.0 - pad_size / 2.0 - get_theme_constant("margin", "Hardwire"))
	for pad: StoragePad in _pads:
		var angle: float = -PI / 2.0 + TAU * pad.index / _pads.size()
		pad.size = Vector2(pad_size, pad_size)
		pad.position = center + Vector2.from_angle(angle) * radius - pad.size / 2.0
		pad.pivot_offset = pad.size / 2.0
