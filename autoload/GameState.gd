extends Node
## Player progress: stats, Cycles, Cores, upgrades, solved slots (SPEC: Stats, currency and slot gating).
## Emits signals on change; SaveManager persists it.

signal stats_changed
signal cycles_changed
signal cores_changed
signal upgrades_changed

var ram: int = 0
var cpu: int = 0
var sto: int = 0
var cycles: int = 0
var cores: int = 0
var last_seen: int = 0
var upgrades: Dictionary = {}
var solved_slots: Array[String] = []
var best_tier_ever: int = 0
var seen_tutorials: Array[String] = []
var settings: Dictionary = {"sound": true, "haptics": true}
var lifetime: Dictionary = {"solves": 0, "fails": 0, "rebuilds": 0}


func _ready() -> void:
	reset_all()


## Back to a fresh save, including Cores, settings and lifetime statistics.
func reset_all() -> void:
	ram = 0
	cpu = 0
	sto = 0
	cycles = 0
	cores = 0
	last_seen = 0
	upgrades = {}
	for id: String in Balance.upgrade_ids():
		upgrades[id] = 0
	solved_slots = []
	best_tier_ever = 0
	seen_tutorials = []
	settings = {"sound": true, "haptics": true}
	lifetime = {"solves": 0, "fails": 0, "rebuilds": 0}
	_emit_all()


func stat(type: String) -> int:
	match type:
		SlotDef.TYPE_RAM:
			return ram
		SlotDef.TYPE_CPU:
			return cpu
		SlotDef.TYPE_STO:
			return sto
	return 0


## SPEC gating rule: every stat meets the slot's requirement on its own.
func is_unlocked(slot: SlotDef) -> bool:
	return missing(slot).is_empty()


## Stat points still missing per stat, e.g. {"cpu": 4}; empty when unlocked.
func missing(slot: SlotDef) -> Dictionary:
	var out := {}
	for type: String in SlotGenerator.TYPES:
		var gap: int = int(slot.req.get(type, 0)) - stat(type)
		if gap > 0:
			out[type] = gap
	return out


func is_solved(slot: SlotDef) -> bool:
	return solved_slots.has(slot.id())


## Highest tier whose slots are unlocked (all requirements are equal within a tier).
func highest_unlocked_tier() -> int:
	var lowest: int = mini(ram, mini(cpu, sto))
	var tier: int = 1
	while Balance.req(tier + 1) <= lowest:
		tier += 1
	return tier


## Highest tier with at least one solved slot in this run, or 0.
func highest_solved_tier() -> int:
	var best: int = 0
	for id: String in solved_slots:
		best = maxi(best, id.get_slice(":", 0).to_int())
	return best


## Credits a solve: stat points to the slot's stat, Cycles to the wallet; marks first solves.
## Returns {stat, cycles, first_solve, new_tier} for the result overlay.
func apply_solve(slot: SlotDef) -> Dictionary:
	var first: bool = not is_solved(slot)
	var before: int = highest_unlocked_tier()
	var gain: Dictionary = Economy.solve_reward(slot, first, int(upgrades.get("overclock", 0)),
		int(upgrades.get("cycle_miner", 0)), cores)
	match slot.type:
		SlotDef.TYPE_RAM:
			ram += gain.stat
		SlotDef.TYPE_CPU:
			cpu += gain.stat
		SlotDef.TYPE_STO:
			sto += gain.stat
	cycles += gain.cycles
	if first:
		solved_slots.append(slot.id())
	best_tier_ever = maxi(best_tier_ever, slot.tier)
	lifetime.solves = int(lifetime.solves) + 1
	stats_changed.emit()
	cycles_changed.emit()
	var after: int = highest_unlocked_tier()
	return {"stat": gain.stat, "cycles": gain.cycles, "first_solve": first, "new_tier": after if after > before else 0}


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func can_buy(id: String) -> bool:
	var level: int = upgrade_level(id)
	return not Economy.is_maxed(id, level) and cycles >= Economy.upgrade_cost(id, level)


## Buys the next level of an upgrade for Cycles. Returns false if maxed or unaffordable.
func buy_upgrade(id: String) -> bool:
	if not can_buy(id):
		return false
	var level: int = upgrade_level(id)
	cycles -= Economy.upgrade_cost(id, level)
	upgrades[id] = level + 1
	cycles_changed.emit()
	upgrades_changed.emit()
	return true


func record_fail() -> void:
	lifetime.fails = int(lifetime.fails) + 1


## Debug helper: raise stats directly (SPEC M1: "a debug button adds stats").
func add_stats(d_ram: int, d_cpu: int, d_sto: int) -> void:
	ram += d_ram
	cpu += d_cpu
	sto += d_sto
	stats_changed.emit()


## Serializes to the save schema in SPEC: Save system (without "version", which SaveManager adds).
func to_dict() -> Dictionary:
	return {
		"stats": {"ram": ram, "cpu": cpu, "sto": sto},
		"cycles": cycles,
		"cores": cores,
		"last_seen": last_seen,
		"upgrades": upgrades.duplicate(),
		"solved_slots": solved_slots.duplicate(),
		"best_tier_ever": best_tier_ever,
		"seen_tutorials": seen_tutorials.duplicate(),
		"settings": settings.duplicate(),
		"lifetime": lifetime.duplicate(),
	}


## Loads from a save Dictionary. Missing or mistyped fields keep their fresh defaults;
## unknown upgrade ids are dropped.
func from_dict(d: Dictionary) -> void:
	reset_all()
	var stats: Dictionary = _dict(d.get("stats"))
	ram = _int(stats.get("ram"), 0)
	cpu = _int(stats.get("cpu"), 0)
	sto = _int(stats.get("sto"), 0)
	cycles = _int(d.get("cycles"), 0)
	cores = _int(d.get("cores"), 0)
	last_seen = _int(d.get("last_seen"), 0)
	var saved_upgrades: Dictionary = _dict(d.get("upgrades"))
	for id: String in upgrades.keys():
		upgrades[id] = _int(saved_upgrades.get(id), 0)
	solved_slots = _strings(d.get("solved_slots"))
	best_tier_ever = _int(d.get("best_tier_ever"), 0)
	seen_tutorials = _strings(d.get("seen_tutorials"))
	var saved_settings: Dictionary = _dict(d.get("settings"))
	for key: String in settings.keys():
		var value: Variant = saved_settings.get(key)
		if value is bool:
			settings[key] = value
	var saved_lifetime: Dictionary = _dict(d.get("lifetime"))
	for key: String in lifetime.keys():
		lifetime[key] = _int(saved_lifetime.get(key), 0)
	_emit_all()


func _emit_all() -> void:
	stats_changed.emit()
	cycles_changed.emit()
	cores_changed.emit()
	upgrades_changed.emit()


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


## JSON numbers arrive as float; negative values are treated as invalid.
static func _int(value: Variant, fallback: int) -> int:
	if (value is float or value is int) and value >= 0:
		return int(value)
	return fallback


static func _strings(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item: Variant in value:
			if item is String:
				out.append(item)
	return out
