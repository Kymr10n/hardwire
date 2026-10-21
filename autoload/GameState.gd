extends Node
## Player progress: stats, Cycles, Cores, upgrades, solved slots (SPEC: Stats, currency and slot
## gating). State and its mutations only; rules live in logic/ (Progress, Economy). Values with
## signals (stats, Cycles, Cores, upgrades, solved slots) change through methods here; plain data
## without listeners (settings, seen_tutorials, last_seen) is written directly. SaveManager
## persists it (and owns the save schema).

signal stats_changed
signal cycles_changed
signal cores_changed
signal upgrades_changed
signal settings_changed

const DEFAULT_SETTINGS := {"sound": true, "haptics": true, "crt": true}
const DEFAULT_LIFETIME := {"solves": 0, "fails": 0, "rebuilds": 0}

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
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var lifetime: Dictionary = DEFAULT_LIFETIME.duplicate()


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
	settings = DEFAULT_SETTINGS.duplicate()
	lifetime = DEFAULT_LIFETIME.duplicate()
	emit_all()


## Stats as {"ram", "cpu", "sto"} for the rules in logic/Progress.gd.
func stats() -> Dictionary:
	return {SlotDef.TYPE_RAM: ram, SlotDef.TYPE_CPU: cpu, SlotDef.TYPE_STO: sto}


func is_solved(slot: SlotDef) -> bool:
	return solved_slots.has(slot.id())


## Credits a solve: stat points to the slot's stat, Cycles to the wallet; marks first solves.
## Returns {stat, cycles, first_solve, new_tier} for the result overlay.
func apply_solve(slot: SlotDef) -> Dictionary:
	var first: bool = not is_solved(slot)
	var before: int = Progress.highest_unlocked_tier(stats())
	var gain: Dictionary = Economy.solve_reward(
		slot, first, upgrade_level("overclock"), upgrade_level("cycle_miner"), cores
	)
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
	var after: int = Progress.highest_unlocked_tier(stats())
	return {
		"stat": gain.stat,
		"cycles": gain.cycles,
		"first_solve": first,
		"new_tier": after if after > before else 0
	}


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


## Buys the next level of an upgrade for Cycles. Returns false if maxed or unaffordable.
func buy_upgrade(id: String) -> bool:
	if not Economy.can_buy(id, upgrade_level(id), cycles):
		return false
	var level: int = upgrade_level(id)
	cycles -= Economy.upgrade_cost(id, level)
	upgrades[id] = level + 1
	cycles_changed.emit()
	upgrades_changed.emit()
	return true


## Prestige (SPEC: Prestige): gain Cores; reset stats, Cycles, upgrades and first-solve flags.
## Keeps Cores, best tier ever, settings, lifetime statistics and seen hints. Returns Cores gained.
func rebuild() -> int:
	if not Progress.can_rebuild(solved_slots):
		return 0
	var gained: int = Progress.rebuild_cores(solved_slots)
	cores += gained
	ram = 0
	cpu = 0
	sto = 0
	cycles = 0
	for id: String in upgrades.keys():
		upgrades[id] = 0
	solved_slots = []
	lifetime.rebuilds = int(lifetime.rebuilds) + 1
	emit_all()
	return gained


## Cycles from idle income or the debug panel.
func add_cycles(amount: int) -> void:
	cycles += amount
	cycles_changed.emit()


func record_fail() -> void:
	lifetime.fails = int(lifetime.fails) + 1


## Debug helper: raise stats directly (SPEC M1: "a debug button adds stats").
func add_stats(d_ram: int, d_cpu: int, d_sto: int) -> void:
	ram += d_ram
	cpu += d_cpu
	sto += d_sto
	stats_changed.emit()


## Settings toggles go through here so listeners (the glass overlay) follow at once.
func set_setting(key: String, value: bool) -> void:
	settings[key] = value
	settings_changed.emit()


## Emits every change signal (after a reset or a load).
func emit_all() -> void:
	stats_changed.emit()
	cycles_changed.emit()
	cores_changed.emit()
	upgrades_changed.emit()
