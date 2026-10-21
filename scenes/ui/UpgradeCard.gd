class_name UpgradeCard
extends PanelContainer
## One upgrade in the shop (SPEC: Upgrade shop): name, a level tag, current and next effect, and a
## buy button with the cost, greyed out when unaffordable or maxed. A purchase flashes the frame.

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
var _level: Label
var _effect: Label
var _frame: StyleBoxFlat


func _init(p_id: String = "") -> void:
	id = p_id


func _ready() -> void:
	var margin: int = get_theme_constant("margin", "Hardwire")
	_frame = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel", _frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", margin / 2)
	add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", margin / 2)
	text.add_child(top)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", get_theme_font_size("card_title", "Hardwire"))
	top.add_child(_title)
	_level = Label.new()
	_level.add_theme_font_size_override("font_size", get_theme_font_size("small", "Hardwire"))
	Ui.tag(_level, get_theme_color("text_dim", "Hardwire"), false)
	top.add_child(_level)
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
	_title.text = NAMES.get(id, id)
	_level.text = "Lv %d%s" % [level, ("/%d" % max_level) if max_level >= 0 else ""]
	if maxed:
		_effect.text = effect_text(id, level) + "  (max)"
		buy_button.text = "Max"
	else:
		_effect.text = "%s  ->  %s" % [effect_text(id, level), effect_text(id, level + 1)]
		buy_button.text = "%d Cyc" % Economy.upgrade_cost(id, level)
	buy_button.disabled = not Economy.can_buy(id, GameState.upgrade_level(id), GameState.cycles)


## The frame turns accent for glow_ms after a purchase (feedback without a layout change).
func flash() -> void:
	_frame.border_color = get_theme_color("accent", "Hardwire")
	var tween: Tween = create_tween()
	tween.tween_interval(get_theme_constant("glow_ms", "Hardwire") / 1000.0)
	tween.tween_callback(_frame.set.bind("border_color", get_theme_color("trace", "Hardwire")))


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
