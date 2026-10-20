class_name Ui
extends RefCounted
## Shared UI helpers for screens built in code (SPEC: Landscape). One code path per screen:
## helpers adapt to the orientation instead of screens having separate layouts.

## Theme `*_pct` constants are percentages.
const PERCENT := 100.0


## True when the node's viewport is wider than tall (Steam Deck, desktop).
static func is_landscape(node: Node) -> bool:
	var size: Vector2 = node.get_viewport().get_visible_rect().size
	return size.x > size.y


## Fills `screen` with margins and returns the content column. With `max_width` > 0, landscape
## widens the side margins so the column is at most that wide. `margin_scale` scales the theme
## margin.
static func screen_root(
	screen: Control, max_width: float = 0.0, margin_scale: float = 0.5
) -> VBoxContainer:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: int = int(screen.get_theme_constant("margin", "Hardwire") * margin_scale)
	var side: int = margin
	if max_width > 0.0 and is_landscape(screen):
		side = maxi(
			margin, int((screen.get_viewport().get_visible_rect().size.x - max_width) / 2.0)
		)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_top", margin)
	root.add_theme_constant_override("margin_bottom", margin)
	root.add_theme_constant_override("margin_left", side)
	root.add_theme_constant_override("margin_right", side)
	screen.add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(
		"separation", screen.get_theme_constant("margin", "Hardwire") / 2
	)
	root.add_child(column)
	return column


## Adds a header (back button and title) to `parent` and returns the title label. The title sits
## right of the button, or below it when `stacked` (narrow landscape side panels).
static func header(
	parent: Control, title: String, on_back: Callable, stacked: bool = false
) -> Label:
	var row := BoxContainer.new()
	row.vertical = stacked
	row.add_theme_constant_override(
		"separation", parent.get_theme_constant("margin", "Hardwire") / 2
	)
	parent.add_child(row)
	var back: Button = button("< Back", on_back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(back)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if stacked else HORIZONTAL_ALIGNMENT_RIGHT
	)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(
		"font_size", parent.get_theme_font_size("header", "Hardwire")
	)
	row.add_child(label)
	return label


## 1 for a press of ui_accept (A, Enter, Space), -1 for its release, 0 otherwise. Echoes ignored.
static func accept_event(event: InputEvent) -> int:
	if event.is_action_pressed("ui_accept", false):
		return 1
	if event.is_action_released("ui_accept"):
		return -1
	return 0


## Gives `screen` keyboard/gamepad focus without showing it (pointer users never see an outline):
## its default_focus() if it has one, else the first visible, enabled button.
static func focus_first(screen: Control) -> void:
	var target: Control = screen.default_focus() if screen.has_method("default_focus") else null
	if target == null:
		for node: Node in screen.find_children("*", "BaseButton", true, false):
			var button := node as BaseButton
			if (
				button.is_visible_in_tree()
				and not button.disabled
				and button.focus_mode != Control.FOCUS_NONE
			):
				target = button
				break
	if target != null:
		target.grab_focus.call_deferred(true)


## Draws the theme's focus outline on a custom-drawn control while it has visible focus.
static func draw_focus(control: Control, rect: Rect2) -> void:
	if control.has_focus(true):
		control.draw_style_box(control.get_theme_stylebox("focus", "Button"), rect)


## A `*_pct` theme constant as a ratio (glow_scale_pct 105 -> 1.05).
static func pct(control: Control, name: String) -> float:
	return control.get_theme_constant(name, "Hardwire") / PERCENT


## A button at least tap_min tall; `wide` makes it the theme's button_width (dialogs, actions).
## Captions are silkscreen: ALL CAPS (DESIGN: Typography); text set later must be caps too.
static func button(text: String, on_pressed: Callable, wide: bool = false) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.pressed.connect(on_pressed)
	# Lets a swipe over a button in a scroll list reach the ScrollContainer (see SlotCard).
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var theme: Theme = ThemeDB.get_project_theme()
	var width: float = theme.get_constant("button_width", "Hardwire") if wide else 0.0
	b.custom_minimum_size = Vector2(width, theme.get_constant("tap_min", "Hardwire"))
	return b


## Lets a custom-drawn control take gamepad/keyboard focus and pointer input (both arrive in its
## _gui_input) and redraw its focus outline when focus changes.
static func make_focusable(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.focus_mode = Control.FOCUS_ALL
	control.focus_entered.connect(control.queue_redraw)
	control.focus_exited.connect(control.queue_redraw)


## Fills `overlay` (dimmed by `dim_alpha`, 0 = none) with a column that centers its children;
## returns the column.
static func centered_column(overlay: Control, dim_alpha: float = 0.0) -> VBoxContainer:
	_backdrop(overlay, dim_alpha)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(
		"separation", overlay.get_theme_constant("margin", "Hardwire")
	)
	overlay.add_child(column)
	return column


## Full-rect overlay with an optional dim layer over what is behind it. Pointer input on the dim
## layer goes to the overlay (which, as a Control, stops it from reaching what is behind).
static func _backdrop(overlay: Control, dim_alpha: float) -> void:
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if dim_alpha <= 0.0:
		return
	var dim := ColorRect.new()
	dim.color = Color(overlay.get_theme_color("bg", "Hardwire"), dim_alpha)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)


## Fills `overlay` with a dimmed backdrop and a centered panel; returns the panel's column.
static func modal(overlay: Control, dim_alpha: float, min_width: float = 0.0) -> VBoxContainer:
	_backdrop(overlay, dim_alpha)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(
		"separation", overlay.get_theme_constant("margin", "Hardwire")
	)
	panel.add_child(column)
	return column


## A centered label in the dim text color (prompts and notes).
static func dim_label(text: String) -> Label:
	var l: Label = label(text)
	l.add_theme_color_override(
		"font_color", ThemeDB.get_project_theme().get_color("text_dim", "Hardwire")
	)
	return l


## A centered label; font_size 0 keeps the theme default.
static func label(text: String, font_size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	return l


## A row (or column, when `vertical`) with the standard half-margin spacing.
static func box(vertical: bool) -> BoxContainer:
	var b := BoxContainer.new()
	b.vertical = vertical
	var margin: int = ThemeDB.get_project_theme().get_constant("margin", "Hardwire")
	b.add_theme_constant_override("separation", margin / 2)
	return b


## A vertical scroll area that fills the space left, follows gamepad/keyboard focus and scrolls
## with a swipe; a finger wobble within scroll_deadzone is still a tap.
static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	s.scroll_deadzone = ThemeDB.get_project_theme().get_constant("scroll_deadzone", "Hardwire")
	return s
