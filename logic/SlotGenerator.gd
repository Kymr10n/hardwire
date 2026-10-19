class_name SlotGenerator
extends RefCounted
## (tier, type) -> SlotDef, including modifier chosen from a hash of (tier, type).
## SPEC: Difficulty curve and slot tiers > Tier generation, Modifiers.

## Overview order of the three slots in a tier row.
const TYPES: Array[String] = [SlotDef.TYPE_RAM, SlotDef.TYPE_CPU, SlotDef.TYPE_STO]


static func make(tier: int, type: String) -> SlotDef:
	var slot := SlotDef.create(tier, type, modifier_for(tier, type))
	var r: int = Balance.req(tier)
	slot.req = {"ram": r, "cpu": r, "sto": r}
	slot.reward = Balance.reward(tier)
	slot.cycles = Balance.cycles(tier)
	return slot


static func tier_slots(tier: int) -> Array[SlotDef]:
	var slots: Array[SlotDef] = []
	for type: String in TYPES:
		slots.append(make(tier, type))
	return slots


## Modifier chance for a tier (0 below modifiers.from_tier).
static func modifier_chance(tier: int) -> float:
	var m: Dictionary = Balance.modifiers()
	if tier < int(m.from_tier):
		return 0.0
	return minf(float(m.chance_max), float(m.chance_base) + float(m.chance_step) * (tier - int(m.from_tier)))


## Deterministic modifier for a slot: low 16 hash bits roll the chance, high 16 bits pick from the pool.
static func modifier_for(tier: int, type: String) -> String:
	var chance: float = modifier_chance(tier)
	if chance <= 0.0:
		return ""
	var h: int = fnv1a32("%d:%s" % [tier, type])
	if (h & 0xFFFF) / 65536.0 >= chance:
		return ""
	var m: Dictionary = Balance.modifiers()
	var pool: Array = m.get("pools", {}).get(type, [])
	if pool.is_empty():
		return ""
	var size: int = 1 if tier < int(m.second_pool_from_tier) else pool.size()
	return str(pool[(h >> 16) % size])


## 32-bit FNV-1a over the UTF-8 bytes of `text` (stable across runs and platforms).
static func fnv1a32(text: String) -> int:
	var h: int = 0x811C9DC5
	for byte: int in text.to_utf8_buffer():
		h = ((h ^ byte) * 0x01000193) & 0xFFFFFFFF
	return h
