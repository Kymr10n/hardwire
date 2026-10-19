extends GutTest
## Placeholder until the generators land (M2+): logic classes load and SlotDef ids are stable.


func test_slot_def_id() -> void:
	var slot := SlotDef.new()
	slot.tier = 3
	slot.type = SlotDef.TYPE_RAM
	assert_eq(slot.id(), "3:ram")
