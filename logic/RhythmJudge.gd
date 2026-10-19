class_name RhythmJudge
extends RefCounted
## Pure function: player press/release timestamps (usec) + a target rhythm -> pass/fail.
## Judges beats (press to next press) and holds (press to release of on-segments longer than one
## step); taps are not timed, so a quick click is fine. A check passes if
## abs(actual - target) <= max(abs_ms, tolerance * target). Only relative times count.
## SPEC: Minigame: CPU > Judging (D-022).
##
## `rhythm` is a RhythmGen attempt: target_ms (on, off, on, ...; 2 * beats - 1 entries),
## step_ms, tolerance, abs_ms.


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


## Returns {passed: bool, reason: String ("" | "count" | "unreleased" | "timing"),
##          failed_beats: Array[int] (beats whose press-to-next-press interval is off),
##          failed_holds: Array[int]}.
static func judge(
	presses_usec: Array[int], releases_usec: Array[int], rhythm: Dictionary
) -> Dictionary:
	var result := {
		"passed": false,
		"reason": "",
		"failed_beats": [] as Array[int],
		"failed_holds": [] as Array[int]
	}
	var target: Array[float] = rhythm.target_ms
	var beats: int = floori((target.size() + 1) / 2.0)
	if presses_usec.size() != beats:
		result.reason = "count"
		return result
	if releases_usec.size() != presses_usec.size():
		result.reason = "unreleased"
		return result
	for beat: int in beats:
		var on: float = target[beat * 2]
		if beat + 1 < beats:
			var interval: float = (presses_usec[beat + 1] - presses_usec[beat]) / 1000.0
			if not _passes(interval, on + target[beat * 2 + 1], rhythm):
				result.failed_beats.append(beat)
		var held: float = (releases_usec[beat] - presses_usec[beat]) / 1000.0
		if on > float(rhythm.step_ms) and not _passes(held, on, rhythm):
			result.failed_holds.append(beat)
	result.passed = result.failed_beats.is_empty() and result.failed_holds.is_empty()
	result.reason = "" if result.passed else "timing"
	return result


static func _passes(actual: float, target: float, rhythm: Dictionary) -> bool:
	return absf(actual - target) <= _allowance(target, rhythm)


static func _allowance(target: float, rhythm: Dictionary) -> float:
	return allowance(target, float(rhythm.tolerance), float(rhythm.abs_ms))
