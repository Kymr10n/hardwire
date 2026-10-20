class_name BevelBox
extends StyleBox
## Plastic bevel (DESIGN: Shape language): a fill with a 1 px outline and `width` px edges, light
## at the top-left and dark at the bottom-right, swapped when `sunken`. With `screws`, a screw sits
## in two opposite corners, its slot at an angle hashed from the rect so it never repeats and
## never changes between frames. With `hazard`, a yellow-black striped band frames the box (the
## Rebuild dialog only). Colors and sizes come from the theme that owns the instance.

## Screw inset from the corner and slot length, as fractions of the screw size.
const SCREW_INSET := 1.0
const SLOT_LENGTH := 0.7
const SLOT_WIDTH := 2.0
## Hazard stripe pitch as a multiple of the band width.
const STRIPE_PITCH := 2.0

@export var bg: Color = Color.WHITE
@export var light: Color = Color.WHITE
@export var dark: Color = Color.BLACK
@export var outline: Color = Color.BLACK
@export var metal: Color = Color.GRAY
@export var width: int = 2
@export var sunken: bool = false
@export var screws: bool = false
@export var screw_size: float = 0.0
@export var hazard: bool = false
@export var hazard_color: Color = Color.YELLOW
@export var hazard_width: float = 0.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if hazard:
		_stripes(to_canvas_item, rect)
		rect = rect.grow(-hazard_width)
	RenderingServer.canvas_item_add_rect(to_canvas_item, rect, outline)
	var inner: Rect2 = rect.grow(-1)
	RenderingServer.canvas_item_add_rect(to_canvas_item, inner, bg)
	var top: Color = dark if sunken else light
	var bottom: Color = light if sunken else dark
	var w: float = width
	var edges: Array = [
		[Rect2(inner.position, Vector2(inner.size.x, w)), top],
		[Rect2(inner.position, Vector2(w, inner.size.y)), top],
		[Rect2(inner.position + Vector2(0, inner.size.y - w), Vector2(inner.size.x, w)), bottom],
		[Rect2(inner.position + Vector2(inner.size.x - w, 0), Vector2(w, inner.size.y)), bottom],
	]
	for edge: Array in edges:
		RenderingServer.canvas_item_add_rect(to_canvas_item, edge[0], edge[1])
	if screws:
		var inset: float = screw_size * SCREW_INSET
		_screw(to_canvas_item, inner.position + Vector2(inset, inset))
		_screw(to_canvas_item, inner.end - Vector2(inset, inset))


## Diagonal stripes over the whole rect, clipped to it; the bevel drawn inside leaves only the
## band showing.
func _stripes(to_canvas_item: RID, rect: Rect2) -> void:
	RenderingServer.canvas_item_add_rect(to_canvas_item, rect, hazard_color)
	var frame := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	var h: float = rect.size.y
	var pitch: float = hazard_width * STRIPE_PITCH
	var half: float = pitch / 2.0
	var x: float = rect.position.x - h
	while x < rect.end.x:
		var stripe := PackedVector2Array(
			[
				Vector2(x, rect.end.y),
				Vector2(x + h, rect.position.y),
				Vector2(x + h + half, rect.position.y),
				Vector2(x + half, rect.end.y),
			]
		)
		for part: PackedVector2Array in Geometry2D.intersect_polygons(stripe, frame):
			RenderingServer.canvas_item_add_polygon(
				to_canvas_item, part, PackedColorArray([outline])
			)
		x += pitch


func _screw(to_canvas_item: RID, center: Vector2) -> void:
	var r: float = screw_size / 2.0
	RenderingServer.canvas_item_add_circle(to_canvas_item, center, r, outline)
	RenderingServer.canvas_item_add_circle(to_canvas_item, center, r - 1, metal)
	var angle: float = fposmod(float(hash(center)), PI)
	var half: Vector2 = Vector2.from_angle(angle) * r * SLOT_LENGTH
	RenderingServer.canvas_item_add_line(
		to_canvas_item, center - half, center + half, outline, SLOT_WIDTH
	)
