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

# TODO(M6): static func upgrade_cost(id: String, level: int) -> int
# TODO(M7): static func cores_for(highest_tier_solved: int) -> int
# TODO(M7): static func idle_cycles(seconds_away: int, t_max: int, miner_lvl: int, cores: int) -> int
