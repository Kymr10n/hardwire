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

var buy_button: Button
var _title: Label
var _effect: Label


func _init(p_id: String = "") -> void:
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
	buy_button = Ui.button("", func() -> void: buy_pressed.emit(id), true)
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy_button)
	refresh()


func refresh() -> void:
	var level: int = GameState.upgrade_level(id)
	var max_level: int = int(Balance.upgrade(id).max_level)
	var maxed: bool = Economy.is_maxed(id, level)
	_title.text = (
		"%s  Lv %d%s" % [NAMES.get(id, id), level, ("/%d" % max_level) if max_level >= 0 else ""]
	)
	if maxed:
		_effect.text = effect_text(id, level) + "  (max)"
		buy_button.text = "Max"
	else:
		_effect.text = "%s  ->  %s" % [effect_text(id, level), effect_text(id, level + 1)]
		buy_button.text = "%d Cyc" % Economy.upgrade_cost(id, level)
	buy_button.disabled = not Economy.can_buy(id, GameState.upgrade_level(id), GameState.cycles)


## Human-readable total effect at a level.
static func effect_text(upgrade_id: String, level: int) -> String:
	var e: float = float(Balance.upgrade(upgrade_id).effect_per_level) * level
	match upgrade_id:
		"replay_buffer":
			return "Storage: %d replays" % int(e)
		"longer_exposure":
			return "RAM: +%d%% show time" % roundi(e * Ui.PERCENT)
		"metronome":
			return "CPU: +%d pts tolerance" % roundi(e * Ui.PERCENT)
		"time_dilation":
			return "All: +%d%% input time" % roundi(e * Ui.PERCENT)
		"overclock":
			return "+%d%% stat rewards" % roundi(e * Ui.PERCENT)
		"cycle_miner":
			return "+%d%% Cycles" % roundi(e * Ui.PERCENT)
	return str(e)
