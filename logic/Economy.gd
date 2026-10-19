class_name Economy
extends RefCounted
## Rewards, upgrade costs, multipliers, prestige Cores, idle income.
## SPEC: Stats/currency, Difficulty curve > Economy formulas, Upgrade shop, Prestige, Idle income.


## Permanent prestige multiplier: 1 + core_bonus x cores.
static func core_multiplier(cores: int) -> float:
	return 1.0 + Balance.get_num("economy", "core_bonus") * cores


## Stat points and Cycles for one solve. All factors multiply; the results are rounded.
static func solve_reward(slot: SlotDef, first_solve: bool, overclock_lvl: int, miner_lvl: int, cores: int) -> Dictionary:
	var mult: float = core_multiplier(cores)
	if first_solve:
		mult *= Balance.get_num("economy", "first_solve_mult")
	if not slot.modifier.is_empty():
		mult *= Balance.get_num("economy", "modifier_mult")
	var stat_mult: float = 1.0 + float(Balance.upgrade("overclock").effect_per_level) * overclock_lvl
	var cycle_mult: float = 1.0 + float(Balance.upgrade("cycle_miner").effect_per_level) * miner_lvl
	return {
		"stat": roundi(slot.reward * mult * stat_mult),
		"cycles": roundi(slot.cycles * mult * cycle_mult),
	}



## Cost of the next level when the upgrade is at `level`: round(base x growth^level).
static func upgrade_cost(id: String, level: int) -> int:
	var u: Dictionary = Balance.upgrade(id)
	return roundi(float(u.base_cost) * pow(float(u.growth), level))


## True when a capped upgrade has reached max_level (max_level < 0 means uncapped).
static func is_maxed(id: String, level: int) -> bool:
	var max_level: int = int(Balance.upgrade(id).max_level)
	return max_level >= 0 and level >= max_level

## Cores a Rebuild pays: max(0, highest_tier_solved - prestige_core_offset).
static func cores_for(highest_tier_solved: int) -> int:
	return maxi(0, highest_tier_solved - Balance.get_int("economy", "prestige_core_offset"))


## Idle Cycles for time away (SPEC: Idle income): replays_per_hour x cycles(t_max) per hour,
## capped at idle.cap_hours, boosted by Cycle miner and Cores (not Overclock). 0 before the first solve
## or for a negative clock.
static func idle_cycles(seconds_away: int, t_max: int, miner_lvl: int, cores: int) -> int:
	if t_max <= 0 or seconds_away <= 0:
		return 0
	var hours: float = minf(seconds_away / 3600.0, Balance.get_num("idle", "cap_hours"))
	var rate: float = Balance.get_num("idle", "replays_per_hour") * Balance.cycles(t_max)
	var miner: float = 1.0 + float(Balance.upgrade("cycle_miner").effect_per_level) * miner_lvl
	return roundi(rate * hours * miner * core_multiplier(cores))


## True if the time away is long enough to offer idle income (idle.min_away_minutes).
static func idle_offer_due(seconds_away: int) -> bool:
	return seconds_away > Balance.get_num("idle", "min_away_minutes") * 60.0
