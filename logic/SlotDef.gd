class_name SlotDef
extends RefCounted
## One puzzle slot on the overview: tier, minigame type, optional modifier, requirements, rewards.
## Built by SlotGenerator; deterministic for a given (tier, type).

const TYPE_STO := "sto"
const TYPE_RAM := "ram"
const TYPE_CPU := "cpu"
const TYPE_NAMES := {TYPE_STO: "Storage", TYPE_RAM: "RAM", TYPE_CPU: "CPU"}
## Stat abbreviations (the stat each minigame raises).
const STAT_NAMES := {TYPE_STO: "STO", TYPE_RAM: "RAM", TYPE_CPU: "CPU"}

var tier: int = 1
var type: String = TYPE_STO
var modifier: String = ""  # "" = none; see balance.json modifiers.pools
var req: Dictionary = {"ram": 0, "cpu": 0, "sto": 0}
var reward: int = 0  # stat points per replay, before multipliers
var cycles: int = 0  # Cycles per replay, before multipliers
## Upgrade levels applied when an attempt is built ({upgrade_id: level}); copied from GameState
## by the puzzle screen so puzzles never read GameState.
var assist: Dictionary = {}


func id() -> String:
	return "%d:%s" % [tier, type]


func assist_level(upgrade_id: String) -> int:
	return int(assist.get(upgrade_id, 0))


## Total assist effect of an upgrade: effect_per_level x level (balance.json upgrades).
func assist_effect(upgrade_id: String) -> float:
	return (
		float(Balance.upgrade(upgrade_id).get("effect_per_level", 0.0)) * assist_level(upgrade_id)
	)


## Builds a bare slot for a given tier, type and (optionally forced) modifier.
## Requirements and rewards are filled in by SlotGenerator (M5).
static func create(p_tier: int, p_type: String, p_modifier: String = "") -> SlotDef:
	var slot := SlotDef.new()
	slot.tier = p_tier
	slot.type = p_type
	slot.modifier = p_modifier
	return slot
