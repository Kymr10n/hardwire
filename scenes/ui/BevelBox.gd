class_name BevelBox
extends StyleBox
## Plastic bevel (DESIGN: Shape language): a fill with a 1 px outline and `width` px edges, light
## at the top-left and dark at the bottom-right, swapped when `sunken`. With `screws`, a screw sits
## in two opposite corners, its slot at an angle hashed from the rect so it never repeats and
## never changes between frames. Colors and sizes come from the theme that owns the instance.

## Screw inset from the corner and slot length, as fractions of the screw size.
const SCREW_INSET := 1.0
const SLOT_LENGTH := 0.7
const SLOT_WIDTH := 2.0

@export var bg: Color = Color.WHITE
@export var light: Color = Color.WHITE
@export var dark: Color = Color.BLACK
@export var outline: Color = Color.BLACK
@export var metal: Color = Color.GRAY
@export var width: int = 2
@export var sunken: bool = false
@export var screws: bool = false
@export var screw_size: float = 0.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	RenderingServer.canvas_item_add_rect(to_canvas_item, rect, outline)
	var inner: Rect2 = rect.grow(-1)
	RenderingServer.canvas_item_add_rect(to_canvas_item, inner, bg)
	var top: Color = dark if sunken else light
	var bottom: Color = light if sunken else dark
	var w: float = width
	var edges := {
		Rect2(inner.position, Vector2(inner.size.x, w)): top,
		Rect2(inner.position, Vector2(w, inner.size.y)): top,
		Rect2(inner.position + Vector2(0, inner.size.y - w), Vector2(inner.size.x, w)): bottom,
		Rect2(inner.position + Vector2(inner.size.x - w, 0), Vector2(w, inner.size.y)): bottom,
	}
	for edge: Rect2 in edges:
		RenderingServer.canvas_item_add_rect(to_canvas_item, edge, edges[edge])
	if screws:
		var inset: float = screw_size * SCREW_INSET
		_screw(to_canvas_item, inner.position + Vector2(inset, inset), 0)
		_screw(to_canvas_item, inner.end - Vector2(inset, inset), 1)


func _screw(to_canvas_item: RID, center: Vector2, corner: int) -> void:
	var r: float = screw_size / 2.0
	RenderingServer.canvas_item_add_circle(to_canvas_item, center, r, outline)
	RenderingServer.canvas_item_add_circle(to_canvas_item, center, r - 1, metal)
	var angle: float = fposmod(float(hash([center, corner])), PI)
	var half: Vector2 = Vector2.from_angle(angle) * r * SLOT_LENGTH
	RenderingServer.canvas_item_add_line(
		to_canvas_item, center - half, center + half, outline, SLOT_WIDTH
	)
