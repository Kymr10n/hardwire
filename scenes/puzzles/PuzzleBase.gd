class_name PuzzleBase
extends Control
## Base for all minigames: COUNTDOWN -> WATCH -> INPUT -> RESULT.
## Receives a SlotDef and an attempt seed; emits solved/failed and never touches GameState.
## Must not own the screen, so a ChainPuzzle (Benchmark slot) can run puzzles in sequence later:
## the host shows phase text and the timer from phase_changed / time_fraction().
##
## Everything is driven from _process with scaled delta (no awaits), so an attempt can be
## aborted or the node freed at any time, and Engine.time_scale speeds it up for debugging.
## On failure the puzzle reveals the answer for flow.fail_reveal_s, then emits failed;
## the host starts the next attempt with setup() + start().

signal solved(result: Dictionary)
signal failed
signal phase_changed(phase: Phase, text: String)

enum Phase { IDLE, COUNTDOWN, WATCH, INPUT, RESULT }

var slot: SlotDef
var attempt_seed: int = 0
var phase: Phase = Phase.IDLE
var time_limit_s: float = 0.0
var time_left_s: float = 0.0

var _phase_t: float = 0.0
var _phase_text: String = ""
var _succeeded: bool = false


func setup(p_slot: SlotDef, p_seed: int) -> void:
	slot = p_slot
	attempt_seed = p_seed


## Builds fresh attempt content from the current seed and starts the countdown.
func start() -> void:
	_succeeded = false
	_build_attempt()
	_set_phase(Phase.COUNTDOWN, _countdown_text(0.0))


## Stops the attempt without emitting anything (back button, screen change).
func abort() -> void:
	phase = Phase.IDLE
	_on_abort()


## A screen rebuilt mid-attempt (rotation, resize) frees the puzzle without abort(); held tones
## and rumble must not outlive it.
func _exit_tree() -> void:
	abort()


## Remaining input time as 0..1 (1 outside the input phase until it starts).
func time_fraction() -> float:
	if phase == Phase.INPUT and time_limit_s > 0.0:
		return clampf(time_left_s / time_limit_s, 0.0, 1.0)
	return 0.0 if phase == Phase.RESULT else 1.0


func _process(delta: float) -> void:
	_phase_t += delta
	match phase:
		Phase.COUNTDOWN:
			if _phase_t >= Balance.get_num("flow", "countdown_s"):
				_set_phase(Phase.WATCH, "Watch")
				_watch_update(0.0)
			else:
				_set_text(_countdown_text(_phase_t))
		Phase.WATCH:
			if _watch_update(_phase_t):
				_set_phase(Phase.INPUT, "Your turn")
		Phase.INPUT:
			time_left_s -= delta
			if time_left_s <= 0.0:
				time_left_s = 0.0
				_on_time_up()
		Phase.RESULT:
			if not _succeeded and _phase_t >= Balance.get_num("flow", "fail_reveal_s"):
				phase = Phase.IDLE
				failed.emit()


func _succeed(result: Dictionary) -> void:
	_succeeded = true
	_set_phase(Phase.RESULT, "Write complete")
	Synth.play_success()
	Haptics.success()
	solved.emit(result)


func _fail() -> void:
	_succeeded = false
	_set_phase(Phase.RESULT, "Corrupted")
	Synth.play_fail()
	Haptics.fail()
	_on_fail_reveal()


func _set_phase(p_phase: Phase, text: String) -> void:
	phase = p_phase
	_phase_t = 0.0
	if p_phase == Phase.INPUT:
		time_left_s = time_limit_s
	_phase_text = text
	_on_phase_entered(p_phase)
	phase_changed.emit(p_phase, text)


func _set_text(text: String) -> void:
	if text != _phase_text:
		_phase_text = text
		phase_changed.emit(phase, text)


func _countdown_text(elapsed: float) -> String:
	var total: float = Balance.get_num("flow", "countdown_s")
	var steps: int = Balance.get_int("flow", "countdown_steps")
	return str(clampi(ceili((total - elapsed) / total * steps), 1, steps))


# --- Overridden by each minigame ---


## Control that should hold gamepad/keyboard focus while this puzzle runs (null = none).
func default_focus() -> Control:
	return null


## Generate content from slot + attempt_seed, reset visuals and set time_limit_s.
func _build_attempt() -> void:
	pass


## Drive the watch playback at `t` seconds into the phase. Return true when playback is over.
func _watch_update(_t: float) -> bool:
	return true


func _on_phase_entered(_p_phase: Phase) -> void:
	pass


## Input time ran out. Default: the attempt fails.
func _on_time_up() -> void:
	_fail()


## Show the correct answer; called when the attempt fails (wrong input or timeout).
func _on_fail_reveal() -> void:
	pass


func _on_abort() -> void:
	pass
