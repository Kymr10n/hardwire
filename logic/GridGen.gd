class_name GridGen
extends RefCounted
## RAM attempt content: grid size, filled cells, timings, from SlotDef + seed.
## SPEC: Minigame: RAM (pattern grid) and Difficulty curve > Minigame formulas.
## Cells are indexed row-major: index = row * n + col.

const MOD_INVERTED := "inverted"
const MOD_ROTATED := "rotated"


## Tier difficulty from the spec formulas, before upgrades.
static func params(tier: int) -> Dictionary:
	var r: Dictionary = Balance.ram()
	var t: int = maxi(1, tier)
	var n: int = Balance.tier_table("ram", "grid_by_tier", t)
	var filled: int = mini(
		int(r.filled_base) + floori((t - 1) / float(r.filled_tier_divisor)),
		floori(float(r.filled_max_ratio) * n * n)
	)
	var show_ms: int = maxi(
		int(r.show_ms_min), int(r.show_ms_start) - int(r.show_ms_step) * (t - 1)
	)
	return {"n": n, "filled": filled, "show_ms": show_ms}


## Builds one attempt. Keys:
## n: grid side; pattern: Array[int] sorted lit cells shown in the watch phase;
## expected: Array[int] sorted cells the player must set (after Inverted / Rotated);
## show_ms, time_limit_s. Assists from slot.assist apply after the tier formulas.
static func make(slot: SlotDef, seed: int) -> Dictionary:
	var p: Dictionary = params(slot.tier)
	var n: int = p.n
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cells: Array[int] = []
	for i: int in n * n:
		cells.append(i)
	# Partial Fisher-Yates with the seeded RNG (Array.shuffle uses the global one).
	for i: int in p.filled:
		var j: int = rng.randi_range(i, cells.size() - 1)
		var tmp: int = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	var pattern: Array[int] = cells.slice(0, p.filled)
	pattern.sort()
	var expected: Array[int] = expected_input(pattern, n, slot.modifier)
	var r: Dictionary = Balance.ram()
	return {
		"n": n,
		"pattern": pattern,
		"expected": expected,
		"show_ms": roundi(p.show_ms * (1.0 + slot.assist_effect("longer_exposure"))),
		"time_limit_s":
		(
			(float(r.input_s_base) + float(r.input_s_per_cell) * expected.size())
			* (1.0 + slot.assist_effect("time_dilation"))
		),
	}


## The sorted cells the player must set for a shown pattern under a modifier.
static func expected_input(pattern: Array[int], n: int, modifier: String) -> Array[int]:
	var out: Array[int] = []
	match modifier:
		MOD_INVERTED:
			for i: int in n * n:
				if not pattern.has(i):
					out.append(i)
		MOD_ROTATED:
			for i: int in pattern:
				out.append(rotate_cw(i, n))
		_:
			out = pattern.duplicate()
	out.sort()
	return out


## Index of cell `i` after rotating the grid 90° clockwise: (row, col) -> (col, n - 1 - row).
static func rotate_cw(i: int, n: int) -> int:
	var row: int = floori(float(i) / n)
	var col: int = i % n
	return col * n + (n - 1 - row)
