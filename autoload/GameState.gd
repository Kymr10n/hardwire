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
