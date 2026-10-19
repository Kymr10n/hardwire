class_name UpgradeCard
extends PanelContainer
## One upgrade in the shop (SPEC: Upgrade shop): name, level, current and next effect, and a buy
## button with the cost, greyed out when unaffordable or maxed.

signal buy_pressed(id: String)

const NAMES := {
	"replay_buffer": "Replay buffer",
	"longer_exposure": "Longer exposure",
	"metronome": "Metronome",
	"time_dilation": "Time dilation",
	"overclock": "Overclock",
	"cycle_miner": "Cycle miner",
}

var id: String = ""

var _title: Label
var _effect: Label
var _buy: Button


func setup(p_id: String) -> void:
	id = p_id


func _ready() -> void:
	var margin: int = get_theme_constant("margin", "Hardwire")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", margin / 2)
	add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", get_theme_font_size("card_title", "Hardwire"))
	text.add_child(_title)
	_effect = Label.new()
	_effect.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
	_effect.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_effect)
	_buy = Button.new()
	var tap: float = get_theme_constant("tap_min", "Hardwire")
	_buy.custom_minimum_size = Vector2(tap * 2.2, tap)
	_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_buy.pressed.connect(func() -> void: buy_pressed.emit(id))
	row.add_child(_buy)
	refresh()


func refresh() -> void:
	var level: int = GameState.upgrade_level(id)
	var max_level: int = int(Balance.upgrade(id).max_level)
	var maxed: bool = Economy.is_maxed(id, level)
	_title.text = "%s  Lv %d%s" % [NAMES.get(id, id), level, ("/%d" % max_level) if max_level >= 0 else ""]
	if maxed:
		_effect.text = effect_text(id, level) + "  (max)"
		_buy.text = "Max"
	else:
		_effect.text = "%s  ->  %s" % [effect_text(id, level), effect_text(id, level + 1)]
		_buy.text = "%d Cyc" % Economy.upgrade_cost(id, level)
	_buy.disabled = not GameState.can_buy(id)


## Human-readable total effect at a level.
static func effect_text(upgrade_id: String, level: int) -> String:
	var e: float = float(Balance.upgrade(upgrade_id).effect_per_level) * level
	match upgrade_id:
		"replay_buffer":
			return "Storage: %d replays" % int(e)
		"longer_exposure":
			return "RAM: +%d%% show time" % roundi(e * 100.0)
		"metronome":
			return "CPU: +%d pts tolerance" % roundi(e * 100.0)
		"time_dilation":
			return "All: +%d%% input time" % roundi(e * 100.0)
		"overclock":
			return "+%d%% stat rewards" % roundi(e * 100.0)
		"cycle_miner":
			return "+%d%% Cycles" % roundi(e * 100.0)
	return str(e)
