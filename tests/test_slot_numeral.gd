extends GutTest
## The Roman numeral of a tool's grade is drawn by the slot, bottom left (task 207), not baked
## into the icons.

const NUMERALS := ["I", "II", "III", "IV", "V"]


func _slot_showing(item: StringName) -> SlotView:
	var slot := SlotView.new()
	add_child_autofree(slot)
	slot.show_stack({"item": item, "count": 1}, false)
	return slot


func test_each_grade_of_a_tool_shows_its_numeral() -> void:
	for grade in NUMERALS.size():
		var slot := _slot_showing(ItemTypes.tool_item(ItemTypes.PICKAXE, grade))
		assert_eq(slot.numeral, NUMERALS[grade])


func test_every_tool_kind_shows_one() -> void:
	for tool_kind: StringName in [
		ItemTypes.HOE,
		ItemTypes.AXE,
		ItemTypes.WATERING_CAN,
		ItemTypes.SCYTHE,
		ItemTypes.SHOVEL,
		ItemTypes.HAMMER
	]:
		assert_eq(_slot_showing(ItemTypes.tool_item(tool_kind, 3)).numeral, "IV", tool_kind)


func test_what_is_not_a_tool_shows_none() -> void:
	assert_eq(_slot_showing(ItemTypes.LOGS).numeral, "")
	assert_eq(_slot_showing(ItemTypes.TURNIP_SEEDS).numeral, "")


func test_an_empty_slot_shows_none() -> void:
	var slot := _slot_showing(ItemTypes.tool_item(ItemTypes.HOE, 4))
	slot.show_stack({}, false)
	assert_eq(slot.numeral, "")


func test_the_hotbar_shows_the_numeral_of_a_tool_in_a_slot() -> void:
	var inventory := Inventory.new()
	inventory.slots[0] = {"item": ItemTypes.tool_item(ItemTypes.AXE, 1), "count": 1}
	var hud := HotbarCase.new_hotbar(inventory)
	add_child_autofree(hud)
	assert_eq(hud._slot_views[0].numeral, "II")


func test_every_grade_has_a_numeral_with_a_glyph() -> void:
	for tool_kind: StringName in [ItemTypes.HOE, ItemTypes.AXE, ItemTypes.WATERING_CAN]:
		for grade in NUMERALS.size():
			var numeral: String = ItemTypes.TYPES[ItemTypes.tool_item(tool_kind, grade)]["numeral"]
			assert_eq(numeral, NUMERALS[grade])
			assert_true(SlotView.NUMERAL_GLYPHS.has(numeral), numeral)


func test_the_glyphs_are_four_pixels_tall_and_one_two_three_three_and_five_wide() -> void:
	var widths := []
	for numeral: String in NUMERALS:
		var glyph: Array = SlotView.NUMERAL_GLYPHS[numeral]
		assert_eq(glyph.size(), 4, numeral)
		widths.append(glyph[0].length())
	assert_eq(widths, [1, 3, 5, 5, 3])


func test_the_numeral_does_not_touch_the_count_in_the_other_corner() -> void:
	var widest: int = SlotView.NUMERAL_GLYPHS["IV"][0].length() + 2 * SlotView.NUMERAL_MARGIN
	assert_lt(SlotView.NUMERAL_CORNER + widest, SlotView.SIZE / 2)
