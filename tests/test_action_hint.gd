extends ResourceCase
## The words of the hint over the hotbar (ActionHint, InteractionRegistry): for every case E
## (Interaction) and Use (ToolUse) decide between, the hint names what really happens.

var _npc: Npc


func _hoe() -> StringName:
	return ItemTypes.tool_item(ItemTypes.HOE, 0)


func _ripe_crop() -> WorldObject:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	var crop := _place(WorldObjectTypes.TURNIP)
	crop.state["growth"] = 3.0 * crop.type_data()["growth_per_stage"]
	return crop


## Asserts that the use on the tile is `use`, that the hint names it, and that using it does it.
func _assert_use_named(use: ToolUse.Use, words: String) -> void:
	assert_eq(_state.use_at(_tile), use)
	assert_eq(ActionHint.use_text(_state, _tile), words)
	assert_eq(_state.use_tile(_tile), use)


# --- E ---


func test_e_has_no_words_with_nothing_to_do() -> void:
	assert_eq(InteractionWords.e_text(_state, _tile), "")


func test_e_names_the_villager_and_goes_before_the_chest() -> void:
	_npc = Npc.create(5, Vector2(_tile) + Vector2(0.5, 0.5), _state.npcs.rules)
	_state.npcs.add(_npc)
	_place(WorldObjectTypes.CHEST)
	assert_eq(InteractionWords.e_text(_state, _tile), "Talk to " + _npc.name)


func test_e_names_getting_on_a_saddled_horse_and_getting_off() -> void:
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(_tile) + Vector2(0.5, 0.5))
	horse.is_saddled = true
	_state.livestock.add(horse)
	assert_eq(InteractionWords.e_text(_state, _tile), "Get on the horse")
	_state.mount(horse)
	assert_eq(InteractionWords.e_text(_state, _tile), "Get off the horse")


func test_e_names_the_chest_and_the_stations() -> void:
	var words := {
		WorldObjectTypes.CHEST: "Open chest",
		WorldObjectTypes.FIREPLACE: "Tend the fire",
		WorldObjectTypes.KILN: "Use kiln",
	}
	for type: StringName in words:
		_world.remove_object(_tile)
		_place(type)
		assert_eq(InteractionWords.e_text(_state, _tile), words[type], str(type))


func test_e_names_the_bed_in_reach() -> void:
	_place(WorldObjectTypes.SLEEPING_BAG)
	assert_eq(InteractionWords.e_text(_state, _tile + Vector2i(0, 1)), "Sleep")


func test_e_names_the_bell() -> void:
	var frame := _place_building_nearby(BuildingTypes.BELL_FRAME)
	var beside := TerrainTileset.tile_centre(frame.origin + Vector2i(-1, 0))
	_state.player.position = beside / TerrainTileset.TILE_SIZE
	assert_eq(InteractionWords.e_text(_state, _state.player.facing_tile()), "Ring the bell")


# --- Use ---


func test_every_use_is_named_or_left_unsaid_on_purpose() -> void:
	var unsaid := [
		ToolUse.Use.NOTHING,
		ToolUse.Use.NEEDS_BETTER_TOOL,
		ToolUse.Use.CAN_EMPTY,
		ToolUse.Use.NO_ROOM,
		ToolUse.Use.RIDING,
		ToolUse.Use.STANDING_ON,
		ToolUse.Use.THE_VILLAGES,
		ToolUse.Use.OUT_OF_REACH,
		# Named apart: the item or the gate gives the words.
		ToolUse.Use.PLACE,
		ToolUse.Use.GATE,
	]
	for use: ToolUse.Use in ToolUse.Use.values():
		assert_true(
			ActionHint.USE_WORDS.has(use) != unsaid.has(use), "%s" % ToolUse.Use.find_key(use)
		)


func test_use_names_tilling_planting_and_harvesting() -> void:
	_hold(_hoe())
	_assert_use_named(ToolUse.Use.TILL, "Till")
	_hold(ItemTypes.TURNIP_SEEDS)
	_assert_use_named(ToolUse.Use.PLANT, "Plant")
	_hold(ItemTypes.NONE)
	_world.remove_object(_tile)
	_ripe_crop()
	_assert_use_named(ToolUse.Use.HARVEST, "Harvest")


func test_use_tells_how_to_get_an_empty_hand_for_a_ripe_crop() -> void:
	_ripe_crop()
	_hold(_hoe())
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING)
	var hotbar := _state.player.inventory
	for slot in Inventory.HOTBAR_SIZE:
		if hotbar.item_in(slot) == ItemTypes.NONE:
			hotbar.slots[slot] = {"item": ItemTypes.LOGS, "count": 1}
	assert_eq(
		ActionHint.use_text(_state, _tile),
		"Harvest with an empty hand: move an item off the hotbar"
	)
	hotbar.slots[(hotbar.selected_slot + 1) % Inventory.HOTBAR_SIZE] = {}
	assert_eq(
		ActionHint.use_text(_state, _tile), "Harvest with an empty hand: pick a free hotbar slot"
	)


func test_use_names_the_watering_can_filling_and_watering() -> void:
	_place(WorldObjectTypes.DRAW_WELL)
	_state.player.can_water = 0
	_hold(ItemTypes.RUSTY_IRON_WATERING_CAN)
	_assert_use_named(ToolUse.Use.FILL_CAN, "Refill")
	_world.remove_object(_tile)
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_world.set_moisture(_tile, 0.0)
	_state.player.can_water = 3
	_assert_use_named(ToolUse.Use.WATER, "Water")


func test_use_says_nothing_for_an_empty_can_over_dry_soil() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_world.set_moisture(_tile, 0.0)
	_state.player.can_water = 0
	_hold(ItemTypes.RUSTY_IRON_WATERING_CAN)
	assert_eq(_state.use_at(_tile), ToolUse.Use.CAN_EMPTY)
	assert_eq(ActionHint.use_text(_state, _tile), "")


func test_use_names_the_saddle_on_and_off_and_petting() -> void:
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(_tile) + Vector2(0.5, 0.5))
	_state.livestock.add(horse)
	_hold(ItemTypes.SADDLE)
	_assert_use_named(ToolUse.Use.SADDLE, "Saddle the horse")
	_hold(ItemTypes.NONE)
	_assert_use_named(ToolUse.Use.UNSADDLE, "Remove saddle")


func test_use_names_petting() -> void:
	var cow := FarmAnimal.new(
		LivestockRules.COW,
		_state.livestock.rules.looks(LivestockRules.COW)[0],
		Vector2(_tile) + Vector2(0.5, 0.6)
	)
	_state.livestock.add(cow)
	_hold(ItemTypes.NONE)
	_assert_use_named(ToolUse.Use.PET, "Pet")


func test_use_names_placing_the_held_item() -> void:
	_state.player.inventory.add(ItemTypes.CHEST, 1)
	_hold(ItemTypes.CHEST)
	_assert_use_named(ToolUse.Use.PLACE, "Place the chest")


func test_use_names_a_hit_by_the_tool_that_cuts() -> void:
	_place(WorldObjectTypes.STONE)
	_hold(ItemTypes.tool_item(ItemTypes.PICKAXE, 0))
	assert_eq(_state.use_at(_tile), ToolUse.Use.HIT)
	assert_eq(ActionHint.use_text(_state, _tile), "Hit")


func test_use_names_the_gate_by_what_it_turns_into() -> void:
	_hold(ItemTypes.NONE)
	_place(WorldObjectTypes.PEN_GATE)
	assert_eq(ActionHint.use_text(_state, _tile), "Open the gate")
	_world.remove_object(_tile)
	_place(WorldObjectTypes.PEN_GATE_OPEN)
	assert_eq(ActionHint.use_text(_state, _tile), "Shut the gate")


func test_use_says_nothing_for_a_tile_out_of_reach() -> void:
	_hold(_hoe())
	assert_eq(ActionHint.use_text(_state, _tile), "Till")
	assert_eq(ActionHint.use_text(_state, _tile + Vector2i(0, 5)), "")


func test_use_names_eating_and_the_lantern_before_any_tile() -> void:
	_state.player.energy = 50.0
	_state.player.inventory.add(ItemTypes.BERRIES, 1)
	_hold(ItemTypes.BERRIES)
	assert_eq(ActionHint.use_text(_state, _tile), "Eat")
	_state.player.energy = 100.0
	assert_eq(ActionHint.use_text(_state, _tile), "")
	_state.player.inventory.add(ItemTypes.LANTERN, 1)
	_hold(ItemTypes.LANTERN)
	assert_eq(ActionHint.use_text(_state, _tile), "", "a lantern with no candle to fit")
	_state.player.inventory.add(ItemTypes.CANDLE, 1)
	assert_eq(ActionHint.use_text(_state, _tile), "Fit a candle")
	assert_true(_state.switch_held_lantern())
	assert_eq(ActionHint.use_text(_state, _tile), "Light the lantern")
	assert_true(_state.switch_held_lantern())
	assert_eq(ActionHint.use_text(_state, _tile), "Put out the lantern")
