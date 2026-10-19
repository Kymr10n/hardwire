class_name Economy
extends RefCounted
## Rewards, upgrade costs, multipliers, prestige Cores, idle income.
## SPEC: Stats/currency, Difficulty curve > Economy formulas, Upgrade shop, Prestige, Idle income.

const SECONDS_PER_HOUR := 3600.0


## Permanent prestige multiplier: 1 + core_bonus x cores.
static func core_multiplier(cores: int) -> float:
	return 1.0 + Balance.get_num("economy", "core_bonus") * cores


## Multiplier of an economy or assist upgrade at `level`: 1 + effect_per_level x level.
static func upgrade_mult(id: String, level: int) -> float:
	return 1.0 + float(Balance.upgrade(id).effect_per_level) * level


## Stat points and Cycles for one solve. All factors multiply; the results are rounded.
static func solve_reward(
	slot: SlotDef, first_solve: bool, overclock_lvl: int, miner_lvl: int, cores: int
) -> Dictionary:
	var mult: float = core_multiplier(cores)
	if first_solve:
		mult *= Balance.get_num("economy", "first_solve_mult")
	if not slot.modifier.is_empty():
		mult *= Balance.get_num("economy", "modifier_mult")
	var stat_mult: float = upgrade_mult("overclock", overclock_lvl)
	var cycle_mult: float = upgrade_mult("cycle_miner", miner_lvl)
	return {
		"stat": roundi(slot.reward * mult * stat_mult),
		"cycles": roundi(slot.cycles * mult * cycle_mult),
	}


## Cost of the next level when the upgrade is at `level`: round(base x growth^level).
static func upgrade_cost(id: String, level: int) -> int:
	var u: Dictionary = Balance.upgrade(id)
	return roundi(float(u.base_cost) * pow(float(u.growth), level))


## True when the next level of `id` is affordable with `cycles` and not past max_level.
static func can_buy(id: String, level: int, cycles: int) -> bool:
	return not is_maxed(id, level) and cycles >= upgrade_cost(id, level)


## True when a capped upgrade has reached max_level (max_level < 0 means uncapped).
static func is_maxed(id: String, level: int) -> bool:
	var max_level: int = int(Balance.upgrade(id).max_level)
	return max_level >= 0 and level >= max_level


## Cores a Rebuild pays: max(0, highest_tier_solved - prestige_core_offset).
static func cores_for(highest_tier_solved: int) -> int:
	return maxi(0, highest_tier_solved - Balance.get_int("economy", "prestige_core_offset"))


## Idle Cycles for time away (SPEC: Idle income): replays_per_hour x cycles(t_max) per hour, capped
## at idle.cap_hours, boosted by Cycle miner and Cores (not Overclock). 0 before the first solve or
## for a negative clock.
static func idle_cycles(seconds_away: int, t_max: int, miner_lvl: int, cores: int) -> int:
	if t_max <= 0 or seconds_away <= 0:
		return 0
	var hours: float = minf(seconds_away / SECONDS_PER_HOUR, Balance.get_num("idle", "cap_hours"))
	var rate: float = Balance.get_num("idle", "replays_per_hour") * Balance.cycles(t_max)
	return roundi(rate * hours * upgrade_mult("cycle_miner", miner_lvl) * core_multiplier(cores))
