extends GutTest
## SlotDef: ids used in the save file, and assist levels copied from the upgrades.


func test_create_and_id() -> void:
	var slot := SlotDef.create(3, SlotDef.TYPE_RAM, "inverted")
	assert_eq([slot.tier, slot.type, slot.modifier], [3, SlotDef.TYPE_RAM, "inverted"])
	assert_eq(slot.id(), "3:ram")


func test_assist_effect() -> void:
	var slot := SlotDef.create(1, SlotDef.TYPE_CPU)
	assert_eq(slot.assist_level("metronome"), 0)
	slot.assist = {"metronome": 2, "time_dilation": 3}
	assert_eq(slot.assist_level("metronome"), 2)
	assert_almost_eq(slot.assist_effect("metronome"), 0.06, 0.0001)
	assert_almost_eq(slot.assist_effect("time_dilation"), 0.45, 0.0001)
