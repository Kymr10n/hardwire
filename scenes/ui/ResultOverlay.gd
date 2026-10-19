class_name ResultOverlay
extends Control
## Success overlay over the puzzle area (SPEC: Result overlay): "Write complete", the stat and
## Cycles gained counting up over flow.reward_countup_s, a note if a new tier unlocked, "Again" and
## "Overview". (Failure needs no overlay: the puzzle reveals the answer and the next attempt
## starts.)

signal again_pressed
signal overview_pressed

const DIM := 0.6
const BUTTON_TAPS := 3.0

var _title: Label
var _gain: Label
var _note: Label
var _stat_name: String = ""
var _stat: int = 0
var _cycles: int = 0
var _t: float = 0.0
var _again: Button


func _ready() -> void:
	var box: VBoxContainer = Ui.modal(self, DIM)
	_title = Ui.label("", get_theme_font_size("phase", "Hardwire"))
	box.add_child(_title)
	_gain = Ui.label("")
	box.add_child(_gain)
	_note = Ui.label("")
	_note.add_theme_color_override("font_color", get_theme_color("text_dim", "Hardwire"))
	box.add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire"))
	box.add_child(buttons)
	_again = Ui.button("Again", again_pressed.emit, BUTTON_TAPS)
	buttons.add_child(_again)
	buttons.add_child(Ui.button("Overview", overview_pressed.emit, BUTTON_TAPS))
	hide()


## gain: {stat, cycles, first_solve, new_tier} from GameState.apply_solve, or {} for no reward line.
func show_result(title: String, accent: Color, stat_name: String, gain: Dictionary) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", accent)
	_stat_name = stat_name
	_stat = int(gain.get("stat", 0))
	_cycles = int(gain.get("cycles", 0))
	_gain.visible = not gain.is_empty()
	var notes: Array[String] = []
	if gain.get("first_solve", false):
		notes.append("First solve x%s" % Balance.get_num("economy", "first_solve_mult"))
	if int(gain.get("new_tier", 0)) > 0:
		notes.append("Tier %d unlocked" % gain.new_tier)
	_note.text = "\n".join(notes)
	_note.visible = not notes.is_empty()
	_t = 0.0
	_update_gain()
	show()
	_again.grab_focus.call_deferred(true)


func _process(delta: float) -> void:
	if visible and _t < Balance.get_num("flow", "reward_countup_s"):
		_t += delta
		_update_gain()


func _update_gain() -> void:
	var f: float = clampf(_t / maxf(0.001, Balance.get_num("flow", "reward_countup_s")), 0.0, 1.0)
	_gain.text = "+%d %s    +%d Cycles" % [roundi(_stat * f), _stat_name, roundi(_cycles * f)]
