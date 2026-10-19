class_name SlotDef
extends RefCounted
## One puzzle slot on the overview: tier, minigame type, optional modifier, requirements, rewards.
## Built by SlotGenerator; deterministic for a given (tier, type).

const TYPE_STO := "sto"
const TYPE_RAM := "ram"
const TYPE_CPU := "cpu"

var tier: int = 1
var type: String = TYPE_STO
var modifier: String = "" # "" = none; see balance.json modifiers.pools
var req: Dictionary = {"ram": 0, "cpu": 0, "sto": 0}
var reward: int = 0 # stat points per replay, before multipliers
var cycles: int = 0 # Cycles per replay, before multipliers


func id() -> String:
	return "%d:%s" % [tier, type]
