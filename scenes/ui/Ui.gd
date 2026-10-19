class_name Ui
extends RefCounted
## Shared UI helpers for screens built in code (SPEC: Landscape). One code path per screen:
## helpers adapt to the orientation instead of screens having separate layouts.


## True when the node's viewport is wider than tall (Steam Deck, desktop).
static func is_landscape(node: Node) -> bool:
	var size: Vector2 = node.get_viewport().get_visible_rect().size
	return size.x > size.y


## Fills `screen` with margins and returns the content column. With `max_width` > 0, landscape
## widens the side margins so the column is at most that wide. `margin_scale` scales the theme margin.
static func screen_root(screen: Control, max_width: float = 0.0, margin_scale: float = 0.5) -> VBoxContainer:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: int = int(screen.get_theme_constant("margin", "Hardwire") * margin_scale)
	var side: int = margin
	if max_width > 0.0 and is_landscape(screen):
		side = maxi(margin, int((screen.get_viewport().get_visible_rect().size.x - max_width) / 2.0))
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_top", margin)
	root.add_theme_constant_override("margin_bottom", margin)
	root.add_theme_constant_override("margin_left", side)
	root.add_theme_constant_override("margin_right", side)
	screen.add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", screen.get_theme_constant("margin", "Hardwire") / 2)
	root.add_child(column)
	return column


## Adds a header (back button and title) to `parent` and returns the title label. The title sits
## right of the button, or below it when `stacked` (narrow landscape side panels).
static func header(parent: Control, title: String, on_back: Callable, stacked: bool = false) -> Label:
	var row := BoxContainer.new()
	row.vertical = stacked
	row.add_theme_constant_override("separation", parent.get_theme_constant("margin", "Hardwire") / 2)
	parent.add_child(row)
	var tap: float = parent.get_theme_constant("tap_min", "Hardwire")
	var back := Button.new()
	back.text = "< Back"
	back.custom_minimum_size = Vector2(tap * 1.5, tap)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(on_back)
	row.add_child(back)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if stacked else HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", parent.get_theme_font_size("header", "Hardwire"))
	row.add_child(label)
	return label
