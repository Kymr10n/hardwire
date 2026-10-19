class_name Progress
extends RefCounted
## Progress rules over the player's state: gating, tiers, rebuild eligibility, idle offers.
## SPEC: Stats, currency and slot gating; Prestige; Idle income. Pure functions, no GameState.

const SECONDS_PER_MINUTE := 60.0


## Stat points still missing per stat, e.g. {"cpu": 4}; empty when every stat meets `req`.
static func missing(req: Dictionary, stats: Dictionary) -> Dictionary:
	var out := {}
	for type: String in SlotGenerator.TYPES:
		var gap: int = int(req.get(type, 0)) - int(stats.get(type, 0))
		if gap > 0:
			out[type] = gap
	return out


## SPEC gating rule: unlocked when every stat meets the requirement on its own.
static func is_unlocked(req: Dictionary, stats: Dictionary) -> bool:
	return missing(req, stats).is_empty()


## Highest tier whose slots are unlocked (all requirements are equal within a tier).
static func highest_unlocked_tier(stats: Dictionary) -> int:
	var lowest: int = int(stats.values().min())
	var tier: int = 1
	while Balance.req(tier + 1) <= lowest:
		tier += 1
	return tier


## Highest tier with at least one solved slot ("tier:type" ids), or 0.
static func highest_solved_tier(solved_slots: Array[String]) -> int:
	var best: int = 0
	for id: String in solved_slots:
		best = maxi(best, id.get_slice(":", 0).to_int())
	return best


## Rebuild needs a solved slot at economy.prestige_min_tier or above.
static func can_rebuild(solved_slots: Array[String]) -> bool:
	return highest_solved_tier(solved_slots) >= Balance.get_int("economy", "prestige_min_tier")


static func rebuild_cores(solved_slots: Array[String]) -> int:
	return Economy.cores_for(highest_solved_tier(solved_slots))


## Seconds since `last_seen`; a negative or missing (0) value counts as zero.
static func seconds_away(last_seen: int, now_unix: int) -> int:
	if last_seen <= 0:
		return 0
	return maxi(0, now_unix - last_seen)


## Idle Cycles to offer for the time since `last_seen`, or 0 when not due (idle.min_away_minutes).
static func idle_offer(
	last_seen: int, now_unix: int, solved_slots: Array[String], miner_lvl: int, cores: int
) -> int:
	var away: int = seconds_away(last_seen, now_unix)
	if away <= Balance.get_num("idle", "min_away_minutes") * SECONDS_PER_MINUTE:
		return 0
	return Economy.idle_cycles(away, highest_solved_tier(solved_slots), miner_lvl, cores)
