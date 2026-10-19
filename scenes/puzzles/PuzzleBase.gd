class_name PuzzleBase
extends Control
## Base for all minigames: COUNTDOWN -> WATCH -> INPUT -> RESULT.
## Receives a SlotDef and an attempt seed; emits solved/failed and never touches GameState.
## Must not own the screen, so a ChainPuzzle (Benchmark slot) can run puzzles in sequence later.

signal solved(result: Dictionary)
signal failed

enum Phase { COUNTDOWN, WATCH, INPUT, RESULT }

var slot: SlotDef
var attempt_seed: int = 0
var phase: Phase = Phase.COUNTDOWN


func setup(p_slot: SlotDef, p_seed: int) -> void:
	slot = p_slot
	attempt_seed = p_seed


# TODO(M2): start(), _begin_watch(), _begin_input(), _finish(success) — shared timer bar and phase label.
# Subclasses override _build_attempt(), _play_watch(), _handle_input().
