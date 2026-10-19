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

# TODO(M1): to_dict() / from_dict() matching the save schema in SPEC: Save system.
# TODO(M5): add_reward(slot_def, first_solve), is_unlocked(slot_def), highest_solved_tier().
# TODO(M6): buy_upgrade(id). TODO(M7): rebuild(), collect_idle().
