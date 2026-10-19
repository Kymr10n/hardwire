class_name SequenceGen
extends RefCounted
## Storage attempt content: pad sequence, pad count, timings, from SlotDef + seed.
## SPEC: Minigame: Storage (color sequence) and Difficulty curve > Minigame formulas.

const MOD_REVERSE := "reverse"
const MOD_DECOY := "decoy"


## Tier difficulty from the spec formulas, before upgrades.
static func params(tier: int) -> Dictionary:
	var s: Dictionary = Balance.storage()
	var t: int = maxi(1, tier)
	var length: int = mini(
		int(s.length_base) + floori(t / float(s.length_tier_divisor)), int(s.length_max)
	)
	var show_ms: int = maxi(
		int(s.show_ms_min), int(s.show_ms_start) - int(s.show_ms_step) * (t - 1)
	)
	var per_item: float = maxf(
		float(s.input_s_per_item_min),
		float(s.input_s_per_item_start) - float(s.input_s_per_item_step) * (t - 1)
	)
	return {
		"length": length,
		"pads": Balance.tier_table("storage", "pads_by_tier", t),
		"show_ms": show_ms,
		"gap_ms": int(s.gap_ms),
		"input_s_per_item": per_item,
	}


## Builds one attempt. Keys:
## sequence: Array[int] pads in playback order; expected: Array[int] pads the player must tap;
## playback: Array[Dictionary] {pad, decoy} items shown during the watch phase;
## pads, show_ms, gap_ms, time_limit_s; replays: Replay button uses (Replay buffer upgrade).
## Assists from slot.assist apply after the tier formulas.
static func make(slot: SlotDef, seed: int) -> Dictionary:
	var p: Dictionary = params(slot.tier)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pads: int = p.pads
	var sequence: Array[int] = []
	for i: int in p.length:
		sequence.append(rng.randi_range(0, pads - 1))

	var expected: Array[int] = sequence.duplicate()
	if slot.modifier == MOD_REVERSE:
		expected.reverse()

	var playback: Array[Dictionary] = []
	for pad: int in sequence:
		playback.append({"pad": pad, "decoy": false})
	if slot.modifier == MOD_DECOY:
		# Between two real items, on a pad different from both neighbors.
		var at: int = rng.randi_range(1, sequence.size() - 1)
		var choices: Array[int] = []
		for pad: int in pads:
			if pad != sequence[at - 1] and pad != sequence[at]:
				choices.append(pad)
		playback.insert(at, {"pad": choices[rng.randi_range(0, choices.size() - 1)], "decoy": true})

	return {
		"sequence": sequence,
		"expected": expected,
		"playback": playback,
		"pads": pads,
		"show_ms": p.show_ms,
		"gap_ms": p.gap_ms,
		"time_limit_s":
		p.length * float(p.input_s_per_item) * (1.0 + slot.assist_effect("time_dilation")),
		"replays": slot.assist_level("replay_buffer"),
	}
