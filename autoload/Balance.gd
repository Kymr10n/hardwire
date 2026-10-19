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


## Returns a top-level section of balance.json, or an empty Dictionary (with an error) if missing.
func section(name: String) -> Dictionary:
	var value: Variant = data.get(name)
	if value is Dictionary:
		return value
	push_error("Balance: missing section '%s'" % name)
	return {}


## Returns a numeric value from a section. Errors and returns 0.0 if missing or not a number.
func get_num(section_name: String, key: String) -> float:
	var value: Variant = section(section_name).get(key)
	if value is float or value is int:
		return float(value)
	push_error("Balance: missing number '%s.%s'" % [section_name, key])
	return 0.0


func get_int(section_name: String, key: String) -> int:
	return int(get_num(section_name, key))


func economy() -> Dictionary:
	return section("economy")


func flow() -> Dictionary:
	return section("flow")


func idle() -> Dictionary:
	return section("idle")


func storage() -> Dictionary:
	return section("storage")


func ram() -> Dictionary:
	return section("ram")


func cpu() -> Dictionary:
	return section("cpu")


func modifiers() -> Dictionary:
	return section("modifiers")


func upgrade(id: String) -> Dictionary:
	var value: Variant = section("upgrades").get(id)
	if value is Dictionary:
		return value
	push_error("Balance: unknown upgrade '%s'" % id)
	return {}


## Upgrade ids in balance.json order (also the keys of the save file's "upgrades" object).
func upgrade_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in section("upgrades").keys():
		ids.append(str(id))
	return ids


## Looks up a [[from_tier, value], ...] table in a section: the value of the last row with from_tier <= tier.
func tier_table(section_name: String, key: String, tier: int) -> int:
	var table: Variant = section(section_name).get(key)
	if not (table is Array) or table.is_empty():
		push_error("Balance: missing tier table '%s.%s'" % [section_name, key])
		return 0
	var value: int = int(table[0][1])
	for row: Variant in table:
		if tier >= int(row[0]):
			value = int(row[1])
	return value


# --- Economy formulas (SPEC: Difficulty curve > Economy formulas) ---

## Stat requirement per stat for a tier: req_factor x (T - 1)^req_exponent.
func req(tier: int) -> int:
	return int(get_num("economy", "req_factor") * pow(maxi(0, tier - 1), get_num("economy", "req_exponent")))


## Stat points per replay, before multipliers: T + reward_offset.
func reward(tier: int) -> int:
	return tier + get_int("economy", "reward_offset")


## Cycles per replay, before multipliers: cycles_per_tier x T.
func cycles(tier: int) -> int:
	return get_int("economy", "cycles_per_tier") * tier
