extends PuzzleBase
## CPU minigame: copy the rhythm by holding the central tile. SPEC: Minigame: CPU.
## Presses and releases are timestamped with Time.get_ticks_usec() inside _input, not _process;
## RhythmJudge compares relative intervals. Input ends 600 ms after the last beat is released,
## or once no input could pass any more; no first press within the timeout fails.

var _attempt: Dictionary = {}
var _tile: CpuTile
var _hint: Label
var _presses: Array[int] = []
var _releases: Array[int] = []
var _holding: bool = false
var _touch_index: int = -1
var _tone_id: int = 0
var _watch_beat: int = -1
var _last_result: Dictionary = {}


func _ready() -> void:
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	add_child(_hint)
	_tile = CpuTile.new()
	add_child(_tile)
	resized.connect(_layout)
	_layout()


func tile() -> CpuTile:
	return _tile


func attempt() -> Dictionary:
	return _attempt


## Judge output of the last finished input (for tests and debugging).
func last_result() -> Dictionary:
	return _last_result


## Registers a press at `usec` (called from _input with Time.get_ticks_usec(); public for tests).
func press_at(usec: int) -> void:
	if phase != Phase.INPUT or _holding:
		return
	if _presses.size() >= _attempt.beats:
		_fail()
		return
	if _presses.is_empty():
		time_limit_s = (_attempt.max_total_ms + _grace_ms()) / 1000.0
		time_left_s = time_limit_s
	_presses.append(usec)
	_holding = true
	_tile.lit = true
	_start_tone()
	Haptics.pulse()
	queue_redraw()


## Registers a release at `usec` (public for tests).
func release_at(usec: int) -> void:
	if phase != Phase.INPUT or not _holding:
		return
	_holding = false
	_releases.append(usec)
	_tile.lit = false
	_stop_tone()
	if _releases.size() == _attempt.beats:
		time_left_s = minf(time_left_s, _grace_ms() / 1000.0)


func _input(event: InputEvent) -> void:
	if phase != Phase.INPUT:
		return
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	var now: int = Time.get_ticks_usec()
	if touch.pressed and not _holding and _tile.get_global_rect().has_point(touch.position):
		_touch_index = touch.index
		get_viewport().set_input_as_handled()
		press_at(now)
	elif not touch.pressed and _holding and touch.index == _touch_index:
		get_viewport().set_input_as_handled()
		release_at(now)


func _process(delta: float) -> void:
	super._process(delta)
	if phase == Phase.RESULT and not _succeeded:
		# Silent replay of the target, compressed into the answer reveal.
		var reveal_s: float = Balance.get_num("flow", "fail_reveal_s")
		var t_ms: float = _phase_t / reveal_s * _attempt.total_ms
		_tile.lit = _segment_at(t_ms) % 2 == 0


func _build_attempt() -> void:
	_attempt = RhythmGen.make(slot, attempt_seed)
	time_limit_s = _attempt.first_press_timeout_s
	_presses.clear()
	_releases.clear()
	_holding = false
	_touch_index = -1
	_watch_beat = -1
	_last_result = {}
	_stop_tone()
	_tile.lit = false
	match slot.modifier:
		RhythmGen.MOD_AUDIO_ONLY:
			_hint.text = "Listen"
		RhythmGen.MOD_SYNCOPATED:
			_hint.text = "Half steps"
		_:
			_hint.text = ""
	queue_redraw()


func _watch_update(t: float) -> bool:
	var segment: int = _segment_at(t * 1000.0)
	if segment < 0:
		_set_watch_on(false)
		return true
	var on: bool = segment % 2 == 0
	_set_watch_on(on)
	var beat: int = floori(segment / 2.0)
	if beat != _watch_beat:
		_watch_beat = beat
		queue_redraw()
	return false


func _set_watch_on(on: bool) -> void:
	if on == (_tone_id != 0):
		return
	if on:
		_start_tone()
	else:
		_stop_tone()
	_tile.lit = on and slot.modifier != RhythmGen.MOD_AUDIO_ONLY


func _on_phase_entered(p_phase: Phase) -> void:
	if p_phase != Phase.WATCH:
		_watch_beat = -1
	queue_redraw()


func _on_time_up() -> void:
	if _presses.is_empty():
		_fail()
		return
	_last_result = RhythmJudge.judge(_presses, _releases, _attempt.target_ms, _attempt.tolerance, _attempt.abs_ms)
	if _last_result.passed:
		_release_tile()
		_succeed({"slot_id": slot.id(), "judge": _last_result})
	else:
		_fail()


func _fail() -> void:
	_release_tile()
	super._fail()


func _on_abort() -> void:
	_release_tile()


func _release_tile() -> void:
	_holding = false
	_stop_tone()
	_tile.lit = false


func _start_tone() -> void:
	if _tone_id == 0:
		_tone_id = Synth.start_tone()
		if _tone_id == 0:
			_tone_id = -1 # sound off: still track the on state


func _stop_tone() -> void:
	if _tone_id > 0:
		Synth.stop_tone(_tone_id)
	_tone_id = 0


## Index of the target segment containing t_ms (even = on), or -1 past the end.
func _segment_at(t_ms: float) -> int:
	var acc: float = 0.0
	var target: Array[float] = _attempt.target_ms
	for i: int in target.size():
		acc += target[i]
		if t_ms < acc:
			return i
	return -1


func _grace_ms() -> float:
	return Balance.get_num("cpu", "end_grace_ms")


func _layout() -> void:
	if _tile == null:
		return
	var margin: float = get_theme_constant("margin", "Hardwire")
	var row_h: float = get_theme_constant("tap_min", "Hardwire")
	var side: float = maxf(0.0, minf(size.x - 2.0 * margin, size.y - 3.0 * row_h) * 0.75)
	_tile.size = Vector2(side, side)
	_tile.position = (size - _tile.size) / 2.0
	_tile.pivot_offset = _tile.size / 2.0
	_hint.position = Vector2(0.0, _tile.position.y - row_h - margin / 2.0)
	_hint.size = Vector2(size.x, row_h)
	queue_redraw()


## Beat dots under the tile: filled per press in the input phase, per played beat while watching.
func _draw() -> void:
	if _attempt.is_empty() or _tile == null:
		return
	var beats: int = _attempt.beats
	var r: float = get_theme_constant("tap_min", "Hardwire") * 0.12
	var gap: float = r * 3.0
	var y: float = _tile.position.y + _tile.size.y + get_theme_constant("margin", "Hardwire") + r
	var x0: float = size.x / 2.0 - gap * (beats - 1) / 2.0
	var filled: int = _presses.size()
	if phase == Phase.WATCH:
		filled = _watch_beat + 1
	var accent: Color = get_theme_color("cpu", "Hardwire")
	for i: int in beats:
		var c := Vector2(x0 + gap * i, y)
		if i < filled:
			draw_circle(c, r, accent)
		else:
			draw_arc(c, r, 0.0, TAU, 24, get_theme_color("text_dim", "Hardwire"), r * 0.3, true)
