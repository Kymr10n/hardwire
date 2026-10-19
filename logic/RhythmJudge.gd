class_name RhythmJudge
extends RefCounted
## Pure function: player press/release timestamps (usec) + target segments (ms) -> pass/fail per
## segment. A segment passes if abs(actual - target) <= max(abs_ms, tolerance * target). Only
## relative intervals count: the clock starts at the first press. SPEC: Minigame: CPU > Judging.


## Allowed deviation for one segment.
static func allowance(target_ms: float, tolerance: float, abs_ms: float) -> float:
	return maxf(abs_ms, tolerance * target_ms)


## Longest total rhythm (first press to last release) in which every segment can still pass.
static func max_total_ms(target_ms: Array[float], tolerance: float, abs_ms: float) -> float:
	var total: float = 0.0
	for t: float in target_ms:
		total += t + allowance(t, tolerance, abs_ms)
	return total


## Judges one attempt. target_ms alternates on, off, on, ... and has 2 * beats - 1 entries.
## Returns {passed: bool, reason: String ("" | "count" | "unreleased" | "timing"),
##          actual_ms: Array[float], ok: Array[bool]} (actual_ms / ok only when counts match).
static func judge(
	presses_usec: Array[int],
	releases_usec: Array[int],
	target_ms: Array[float],
	tolerance: float,
	abs_ms: float
) -> Dictionary:
	var result := {
		"passed": false, "reason": "", "actual_ms": [] as Array[float], "ok": [] as Array[bool]
	}
	var beats: int = floori((target_ms.size() + 1) / 2.0)
	if presses_usec.size() != beats:
		result.reason = "count"
		return result
	if releases_usec.size() != presses_usec.size():
		result.reason = "unreleased"
		return result

	var actual: Array[float] = []
	for i: int in beats:
		actual.append((releases_usec[i] - presses_usec[i]) / 1000.0)
		if i + 1 < beats:
			actual.append((presses_usec[i + 1] - releases_usec[i]) / 1000.0)
	var ok: Array[bool] = []
	var all_ok: bool = true
	for i: int in actual.size():
		var passed: bool = (
			absf(actual[i] - target_ms[i]) <= allowance(target_ms[i], tolerance, abs_ms)
		)
		ok.append(passed)
		all_ok = all_ok and passed
	result.actual_ms = actual
	result.ok = ok
	result.passed = all_ok
	result.reason = "" if all_ok else "timing"
	return result
