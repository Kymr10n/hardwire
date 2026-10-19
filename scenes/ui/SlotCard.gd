class_name SlotCard
extends Button
## One slot on the overview (SPEC: Slot card states): locked (greyed, missing stats),
## unlocked and never solved (accent border, NEW badge), solved (normal), modifier (icon in the corner).
## Shows what the next solve pays. Drawn entirely in _draw; the Button handles presses.

const MOD_GLYPHS := {
	"reverse": "<", "decoy": "?", "inverted": "~", "rotated": "R", "audio_only": "A", "syncopated": "S",
}

var slot: SlotDef

var _style := StyleBoxFlat.new()


func setup(p_slot: SlotDef) -> void:
	slot = p_slot
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, get_theme_constant("tap_min", "Hardwire") * 2.2)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh()


func refresh() -> void:
	disabled = not GameState.is_unlocked(slot)
	queue_redraw()


func _draw() -> void:
	if slot == null:
		return
	var font: Font = get_theme_default_font()
	var accent: Color = get_theme_color(slot.type, "Hardwire")
	var text_color: Color = get_theme_color("text", "Hardwire")
	var dim: Color = get_theme_color("text_dim", "Hardwire")
	var locked: bool = not GameState.is_unlocked(slot)
	var solved: bool = GameState.is_solved(slot)
	var pad: float = get_theme_constant("margin", "Hardwire") * 0.4
	var title_size: int = get_theme_font_size("card_title", "Hardwire")
	var body_size: int = get_theme_font_size("card_body", "Hardwire")
	var small_size: int = get_theme_font_size("small", "Hardwire")

	_style.set_corner_radius_all(18)
	_style.set_border_width_all(4 if not locked and not solved else 2)
	_style.bg_color = get_theme_color("card_locked" if locked else "card", "Hardwire")
	if get_draw_mode() == DRAW_PRESSED:
		_style.bg_color = _style.bg_color.lightened(0.08)
	_style.border_color = accent if not locked and not solved else get_theme_color("trace", "Hardwire")
	draw_style_box(_style, Rect2(Vector2.ZERO, size))

	var title_color: Color = dim if locked else accent
	draw_string(font, Vector2(pad, 50), SlotDef.TYPE_NAMES[slot.type], HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)

	if not slot.modifier.is_empty():
		var c := Vector2(size.x - pad - 18, 38)
		draw_circle(c, 20, dim if locked else accent)
		draw_string(font, c + Vector2(-20, 10), MOD_GLYPHS.get(slot.modifier, "*"), HORIZONTAL_ALIGNMENT_CENTER, 40, small_size,
			get_theme_color("bg", "Hardwire"))
		draw_string(font, Vector2(pad, size.y - pad), slot.modifier.capitalize(), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 2 * pad, small_size, dim)

	var y: float = 100.0
	if locked:
		var missing: Dictionary = GameState.missing(slot)
		for type: String in SlotGenerator.TYPES:
			if missing.has(type):
				draw_string(font, Vector2(pad, y), "%s %d more" % [SlotDef.STAT_NAMES[type], missing[type]],
					HORIZONTAL_ALIGNMENT_LEFT, size.x - 2 * pad, small_size, dim)
				y += 34
	else:
		var gain: Dictionary = Economy.solve_reward(slot, not solved, int(GameState.upgrades.get("overclock", 0)),
			int(GameState.upgrades.get("cycle_miner", 0)), GameState.cores)
		draw_string(font, Vector2(pad, y), "+%d %s" % [gain.stat, SlotDef.STAT_NAMES[slot.type]],
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 2 * pad, body_size, text_color)
		draw_string(font, Vector2(pad, y + 38), "+%d Cyc" % gain.cycles, HORIZONTAL_ALIGNMENT_LEFT, size.x - 2 * pad, body_size, text_color)
		if not solved:
			var badge := Rect2(Vector2(size.x - pad - 84, size.y - pad - 40), Vector2(84, 40))
			var badge_style := StyleBoxFlat.new()
			badge_style.bg_color = accent
			badge_style.set_corner_radius_all(10)
			draw_style_box(badge_style, badge)
			draw_string(font, badge.position + Vector2(0, 30), "NEW", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, small_size,
				get_theme_color("bg", "Hardwire"))
