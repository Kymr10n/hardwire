class_name RhythmJudge
extends RefCounted
## Pure function: player press/release timestamps (usec) + target segments (ms) -> pass/fail per segment.
## A segment passes if abs(actual - target) <= max(tolerance_abs_ms, tolerance * target).
## SPEC: Minigame: CPU (rhythm) > Judging. Must be fully unit-tested (M4).

# TODO(M4): static func judge(presses_usec: Array[int], releases_usec: Array[int],
#                               target_ms: Array[float], tolerance: float, abs_ms: float) -> Dictionary
