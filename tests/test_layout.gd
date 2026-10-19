extends "res://tests/hardwire_test.gd"
## Every screen in portrait (phone) and landscape (16:9, Steam Deck 16:10): controls stay on
## screen, tap targets keep the minimum size, pads and cells don't overlap (SPEC: Landscape).

const SIZES: Array[Vector2i] = [Vector2i(1080, 1920), Vector2i(1920, 1080), Vector2i(1920, 1200)]
var screens := {
	"overview": OverviewScreen,
	"shop": ShopScreen,
	"settings": SettingsScreen,
	"licenses": LicensesScreen,
	"debug": DebugMenu,
}


func _open(screen: Control, size: Vector2i) -> Control:
	in_viewport(screen, size)
	await wait_process_frames(2)
	return screen


## Buttons outside scroll areas must be fully visible and at least tap_min tall.
func _check_controls(screen: Control, label: String) -> void:
	var view := Rect2(Vector2.ZERO, screen.get_viewport().get_visible_rect().size)
	var tap: float = screen.get_theme_constant("tap_min", "Hardwire")
	for node: Node in screen.find_children("*", "BaseButton", true, false):
		var button := node as Control
		if not button.is_visible_in_tree() or _in_scroll(button):
			continue
		var rect: Rect2 = button.get_global_rect()
		assert_true(
			view.encloses(rect.grow(-1.0)), "%s: %s at %s is off screen" % [label, button, rect]
		)
		assert_gte(rect.size.y, tap - 0.5, "%s: %s is shorter than tap_min" % [label, button])


func _in_scroll(node: Node) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func _assert_no_overlap(rects: Array[Rect2], label: String) -> void:
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			assert_false(
				rects[i].intersects(rects[j]), "%s: items %d and %d overlap" % [label, i, j]
			)


func test_menu_screens() -> void:
	set_stats(140)
	for size: Vector2i in SIZES:
		for name: String in screens:
			var screen: Control = await _open(screens[name].new(), size)
			assert_eq(screen.size, Vector2(size), "%s fills the viewport" % name)
			_check_controls(screen, "%s %s" % [name, size])
			screen.get_parent().queue_free()


func test_storage_pads_at_every_size() -> void:
	for size: Vector2i in SIZES:
		var screen := PuzzleScreen.new()
		var slot := SlotDef.create(20, SlotDef.TYPE_STO)
		slot.assist = {"replay_buffer": 1}
		screen.setup(slot)
		await _open(screen, size)
		run_until(screen.puzzle, PuzzleBase.Phase.INPUT)
		_check_controls(screen, "storage %s" % size)
		var rects: Array[Rect2] = [screen.puzzle.replay_button.get_global_rect()]
		for pad: StoragePad in screen.puzzle.pads():
			assert_gte(pad.size.x, 160.0, "pads are at least 160 px")
			assert_true(
				Rect2(Vector2.ZERO, Vector2(size)).encloses(pad.get_global_rect()), "pad on screen"
			)
			rects.append(pad.get_global_rect())
		assert_eq(rects.size(), 9, "8 pads and the Replay button")
		_assert_no_overlap(rects, "storage %s" % size)
		screen.get_parent().queue_free()


func test_ram_cells_at_every_size() -> void:
	for size: Vector2i in SIZES:
		var screen := PuzzleScreen.new()
		screen.setup(SlotDef.create(20, SlotDef.TYPE_RAM))
		await _open(screen, size)
		_check_controls(screen, "ram %s" % size)
		var grid: RamGrid = screen.puzzle.grid()
		assert_eq(grid.n, 6)
		assert_gte(grid.cell_rect(0).size.x, 120.0, "cells are at least 120 px")
		assert_eq(grid.cell_at(grid.cell_rect(7).get_center()), 7, "hit test")
		screen.get_parent().queue_free()


func test_cpu_tile_at_every_size() -> void:
	for size: Vector2i in SIZES:
		var screen := PuzzleScreen.new()
		screen.setup(SlotDef.create(10, SlotDef.TYPE_CPU))
		await _open(screen, size)
		_check_controls(screen, "cpu %s" % size)
		var tile: CpuTile = screen.puzzle.tile()
		assert_gte(tile.size.x, 400.0, "tile is large")
		assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(tile.get_global_rect()))
		screen.get_parent().queue_free()


func test_landscape_uses_side_panels() -> void:
	var overview: Control = await _open(screens.overview.new(), Vector2i(1920, 1080))
	var bar: StatBar = overview.find_children("*", "StatBar", true, false)[0]
	assert_true(bar.vertical, "stats in a sidebar")
	var portrait: Control = await _open(screens.overview.new(), Vector2i(1080, 1920))
	var portrait_bar: StatBar = portrait.find_children("*", "StatBar", true, false)[0]
	assert_false(portrait_bar.vertical, "stats in a row")
