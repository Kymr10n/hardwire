class_name Ui
extends RefCounted
## Shared UI helpers for screens built in code (SPEC: Landscape).


## True when the node's viewport is wider than tall (Steam Deck, desktop).
static func is_landscape(node: Node) -> bool:
	var size: Vector2 = node.get_viewport().get_visible_rect().size
	return size.x > size.y
