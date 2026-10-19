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
var modifier: String = "" # "" = none; see balance.json modifiers.pools
var req: Dictionary = {"ram": 0, "cpu": 0, "sto": 0}
var reward: int = 0 # stat points per replay, before multipliers
var cycles: int = 0 # Cycles per replay, before multipliers


func id() -> String:
	return "%d:%s" % [tier, type]


## Builds a bare slot for a given tier, type and (optionally forced) modifier.
## Requirements and rewards are filled in by SlotGenerator (M5).
static func create(p_tier: int, p_type: String, p_modifier: String = "") -> SlotDef:
	var slot := SlotDef.new()
	slot.tier = p_tier
	slot.type = p_type
	slot.modifier = p_modifier
	return slot
