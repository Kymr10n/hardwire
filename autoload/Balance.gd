extends Node
## Loads data/balance.json and exposes every tuning number and formula from docs/SPEC.md.
## Game code reads numbers only through this autoload, never as literals.

const BALANCE_PATH := "res://data/balance.json"

var data: Dictionary = {}


func _ready() -> void:
	load_balance()


func load_balance() -> void:
	var file := FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if file == null:
		push_error("Balance: cannot open %s" % BALANCE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("Balance: %s is not a JSON object" % BALANCE_PATH)


# TODO(M1): typed accessors per section (economy, storage, ram, cpu, modifiers, upgrades, idle).
# TODO(M5): formula functions req(tier), reward(tier), cycles(tier) — SPEC: Difficulty curve.
