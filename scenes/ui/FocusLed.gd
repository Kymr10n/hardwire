class_name FocusLed
extends StyleBox
## Focus as a lit LED (DESIGN: Buttons): one dot in the top-right corner of the focused element,
## inside its content margin, instead of an outline. Buttons draw it as their focus style; custom
## controls draw it through Ui.draw_focus.

@export var color: Color = Color.WHITE
@export var radius: float = 0.0
@export var inset: float = 0.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var center: Vector2 = rect.position + Vector2(rect.size.x - inset, inset)
	RenderingServer.canvas_item_add_circle(to_canvas_item, center, radius, color)
