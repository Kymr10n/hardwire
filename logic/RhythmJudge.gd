class_name RhythmJudge
extends RefCounted
## Pure function: player press/release timestamps (usec) + a target rhythm -> misses, pass/fail.
## Judged as you play (D-030): a beat's interval (press to next press) is checked once the next
## press exists, a hold (an on-segment longer than one step) once it is released; taps are not
## timed, so a quick click is fine. A check passes if
## abs(actual - target) <= max(abs_ms, tolerance * target). Only relative times count.
## SPEC: Minigame: CPU > Judging.
##
## `rhythm` is a RhythmGen attempt: target_ms (on, off, on, ...; 2 * beats - 1 entries),
## step_ms, tolerance, abs_ms.

const KIND_BEAT := "beat"
const KIND_HOLD := "hold"


## Allowed deviation for one check.
static func allowance(target_ms: float, tolerance: float, abs_ms: float) -> float:
	return maxf(abs_ms, tolerance * target_ms)


## Longest time from the first press to the last release that can still pass: every beat
## interval and the last beat at their upper tolerance (this also caps how long the last beat,
## even a tap, may be held).
static func max_total_ms(rhythm: Dictionary) -> float:
	var target: Array[float] = rhythm.target_ms
	var total: float = 0.0
	for i: int in range(0, target.size(), 2):
		var length: float = target[i] + (target[i + 1] if i + 1 < target.size() else 0.0)
		total += length + _allowance(length, rhythm)
	return total


## Every failing check the input so far determines, in input order:
## {beat: int, kind: KIND_BEAT | KIND_HOLD, delta_ms: float (actual - target)}.
## A beat check reports the beat whose press came early or late (the next one).
static func misses(
	presses_usec: Array[int], releases_usec: Array[int], rhythm: Dictionary
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var target: Array[float] = rhythm.target_ms
	var beats: int = _beats(rhythm)
	for beat: int in mini(beats, presses_usec.size()):
		var on: float = target[beat * 2]
		if beat < releases_usec.size() and on > float(rhythm.step_ms):
			var held: float = (releases_usec[beat] - presses_usec[beat]) / 1000.0
			if not _passes(held, on, rhythm):
				out.append({"beat": beat, "kind": KIND_HOLD, "delta_ms": held - on})
		if beat + 1 < beats and beat + 1 < presses_usec.size():
			var interval: float = (presses_usec[beat + 1] - presses_usec[beat]) / 1000.0
			var want: float = on + target[beat * 2 + 1]
			if not _passes(interval, want, rhythm):
				out.append({"beat": beat + 1, "kind": KIND_BEAT, "delta_ms": interval - want})
	return out


## Verdict once input is over: {passed: bool, reason: "" | "count" | "unreleased" | "timing",
## misses: Array[Dictionary] (see misses())}.
static func judge(
	presses_usec: Array[int], releases_usec: Array[int], rhythm: Dictionary
) -> Dictionary:
	var result := {"passed": false, "reason": "", "misses": [] as Array[Dictionary]}
	if presses_usec.size() != _beats(rhythm):
		result.reason = "count"
	elif releases_usec.size() != presses_usec.size():
		result.reason = "unreleased"
	else:
		result.misses = misses(presses_usec, releases_usec, rhythm)
		result.passed = result.misses.is_empty()
		result.reason = "" if result.passed else "timing"
	return result


static func _beats(rhythm: Dictionary) -> int:
	return floori((rhythm.target_ms.size() + 1) / 2.0)


static func _passes(actual: float, target: float, rhythm: Dictionary) -> bool:
	return absf(actual - target) <= _allowance(target, rhythm)


static func _allowance(target: float, rhythm: Dictionary) -> float:
	return allowance(target, float(rhythm.tolerance), float(rhythm.abs_ms))
