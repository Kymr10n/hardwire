class_name ResultOverlay
extends Control
## Success overlay over the puzzle area (SPEC: Result overlay): "Write complete", the stat and
## Cycles gained counting up over flow.reward_countup_s, a note if a new tier unlocked, "Again" and
## "Overview". (Failure needs no overlay: the puzzle reveals the answer and the next attempt
## starts.)

signal again_pressed
signal overview_pressed

var gain: Label
var note: Label
var _title: Label
var _stat_name: String = ""
var _stat: int = 0
var _cycles: int = 0
var _countup: Tween
var _again: Button


func _ready() -> void:
	var box: VBoxContainer = Ui.modal(self, Ui.pct(self, "overlay_dim_pct"))
	_title = Ui.label("", get_theme_font_size("phase", "Hardwire"))
	_title.uppercase = true
	box.add_child(_title)
	gain = Ui.label("")
	box.add_child(gain)
	note = Ui.dim_label("")
	box.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", get_theme_constant("margin", "Hardwire"))
	box.add_child(buttons)
	_again = Ui.button("Again", again_pressed.emit, true)
	buttons.add_child(_again)
	buttons.add_child(Ui.button("Overview", overview_pressed.emit, true))
	hide()


## gain: {stat, cycles, first_solve, new_tier} from GameState.apply_solve, or {} for no reward line.
func show_result(title: String, stat_name: String, gain: Dictionary) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", get_theme_color("accent", "Hardwire"))
	_stat_name = stat_name
	_stat = int(gain.get("stat", 0))
	_cycles = int(gain.get("cycles", 0))
	gain.visible = not gain.is_empty()
	var notes: Array[String] = []
	if gain.get("first_solve", false):
		notes.append("First solve x%s" % Balance.get_num("economy", "first_solve_mult"))
	if int(gain.get("new_tier", 0)) > 0:
		notes.append("Tier %d unlocked" % gain.new_tier)
	note.text = "\n".join(notes)
	note.visible = not notes.is_empty()
	_set_countup(0.0)
	if _countup:
		_countup.kill()
	_countup = create_tween()
	_countup.tween_method(_set_countup, 0.0, 1.0, Balance.get_num("flow", "reward_countup_s"))
	show()
	_again.grab_focus.call_deferred(true)


## Shows the fraction `f` (0..1) of the reward.
func _set_countup(f: float) -> void:
	gain.text = "+%d %s    +%d Cycles" % [roundi(_stat * f), _stat_name, roundi(_cycles * f)]
