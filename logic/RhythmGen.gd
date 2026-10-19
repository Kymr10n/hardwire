class_name RhythmGen
extends RefCounted
## CPU attempt content: alternating on/off segments in steps, step_ms, tolerance.
## SPEC: Minigame: CPU (rhythm) and Difficulty curve > Minigame formulas.

const MOD_AUDIO_ONLY := "audio_only"
const MOD_SYNCOPATED := "syncopated"


## Tier difficulty from the spec formulas, before upgrades.
static func params(tier: int) -> Dictionary:
	var c: Dictionary = Balance.cpu()
	var t: int = maxi(1, tier)
	return {
		"beats":
		mini(int(c.beats_base) + floori(t / float(c.beats_tier_divisor)), int(c.beats_max)),
		"step_ms": maxi(int(c.step_ms_min), int(c.step_ms_start) - int(c.step_ms_step) * (t - 1)),
		"tolerance":
		maxf(float(c.tolerance_min), float(c.tolerance_start) - float(c.tolerance_step) * (t - 1)),
	}


## Builds one attempt. Keys:
## steps: Array[float] segment lengths in steps (on, off, on, ..., on; 2 * beats - 1 entries);
## target_ms: Array[float] the same in ms; beats, step_ms, tolerance, abs_ms;
## total_ms: target rhythm length; max_total_ms: longest rhythm that can still pass;
## first_press_timeout_s. Assists from slot.assist apply after the tier formulas.
static func make(slot: SlotDef, seed: int) -> Dictionary:
	var p: Dictionary = params(slot.tier)
	var c: Dictionary = Balance.cpu()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var on_choices: Array[float] = _range_steps(int(c.on_steps_min), int(c.on_steps_max))
	var off_choices: Array[float] = _range_steps(int(c.off_steps_min), int(c.off_steps_max))
	var syncopated: bool = slot.modifier == MOD_SYNCOPATED
	var halves: Array[float] = []
	for h: Variant in c.syncopated_steps:
		halves.append(float(h))
	if syncopated:
		on_choices.append_array(halves)
		off_choices.append_array(halves)

	var steps: Array[float] = []
	for i: int in p.beats * 2 - 1:
		var choices: Array[float] = on_choices if i % 2 == 0 else off_choices
		steps.append(choices[rng.randi_range(0, choices.size() - 1)])
	if syncopated and not _has_half(steps):
		steps[rng.randi_range(0, steps.size() - 1)] = halves[rng.randi_range(0, halves.size() - 1)]

	var tolerance: float = p.tolerance + slot.assist_effect("metronome")
	var abs_ms: float = float(c.tolerance_abs_ms)
	var target_ms: Array[float] = []
	var total_ms: float = 0.0
	for s: float in steps:
		target_ms.append(s * p.step_ms)
		total_ms += s * p.step_ms
	return {
		"beats": p.beats,
		"step_ms": p.step_ms,
		"tolerance": tolerance,
		"abs_ms": abs_ms,
		"steps": steps,
		"target_ms": target_ms,
		"total_ms": total_ms,
		"max_total_ms": RhythmJudge.max_total_ms(target_ms, tolerance, abs_ms),
		"first_press_timeout_s":
		float(c.first_press_timeout_s) * (1.0 + slot.assist_effect("time_dilation")),
	}


static func _range_steps(lo: int, hi: int) -> Array[float]:
	var out: Array[float] = []
	for s: int in range(lo, hi + 1):
		out.append(float(s))
	return out


static func _has_half(steps: Array[float]) -> bool:
	for s: float in steps:
		if not is_equal_approx(s, roundf(s)):
			return true
	return false
