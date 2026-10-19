extends Control
## Root scene. Holds the current screen and handles transitions (SPEC: Screens and UX flow).
## Stub: shows a placeholder so the project runs. Replace in M1/M5.


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0d1117")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var label := Label.new()
	label.text = "HARDWIRE\n\nproject stub\nbalance.json loaded: %s\n\nnext: milestone M1\nsee docs/SPEC.md" % str(not Balance.data.is_empty())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color("5ee6ff"))
	add_child(label)
