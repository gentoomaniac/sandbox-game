extends ResourceCase
## Wattle fences and stone walls the player makes (task 203): crafted, put down piece by piece, the
## same world objects the generator lays along the fields, so they join its runs, stop walking, are
## taken down with the same tool for what the piece cost, and are kept through a save.

const PIECES := {
	ItemTypes.WATTLE_FENCE: WorldObjectTypes.WATTLE_FENCE,
	ItemTypes.STONE_WALL: WorldObjectTypes.STONE_WALL,
}


func test_a_wattle_fence_is_made_at_the_workbench_and_a_stone_wall_by_hand() -> void:
	var rules := RecipeRules.default_rules()
	assert_has(rules.recipes_at(&"workbench"), ItemTypes.WATTLE_FENCE)
	assert_eq(rules.skill(ItemTypes.WATTLE_FENCE), &"woodworking")
	assert_has(rules.recipes_at(&""), ItemTypes.STONE_WALL)
	assert_eq(rules.skill(ItemTypes.STONE_WALL), &"masonry")


func test_crafting_takes_the_materials_and_gives_the_pieces() -> void:
	var workbench := _place_beside(WorldObjectTypes.WORKBENCH)
	var crafting := Crafting.new(_state)
	var rules := RecipeRules.default_rules()
	_state.player.skills.set_points(&"woodworking", 10.0)
	_state.player.skills.set_points(&"masonry", 10.0)
	for item in PIECES:
		var station := workbench if rules.station_of(item) == &"workbench" else null
		assert_eq(crafting.craft(item, station), Crafting.Result.MISSING_MATERIALS, item)
		for material in rules.materials(item):
			_state.player.inventory.add(material, rules.materials(item)[material])
		assert_eq(crafting.craft(item, station), Crafting.Result.CRAFTED, item)
		assert_eq(_count(item), rules.count(item), item)


func test_a_piece_is_locked_below_its_skill_level() -> void:
	_state.player.inventory.add(ItemTypes.STONE, 3)
	assert_eq(Crafting.new(_state).craft(ItemTypes.STONE_WALL), Crafting.Result.LOCKED)


func test_taking_a_piece_down_never_gives_more_than_the_recipe_took() -> void:
	var rules := RecipeRules.default_rules()
	for item in PIECES:
		var cost_of_a_piece := {}
		for material: StringName in rules.materials(item):
			cost_of_a_piece[material] = float(rules.materials(item)[material]) / rules.count(item)
		var drops: Dictionary = WorldObjectTypes.TYPES[PIECES[item]]["drops"]
		for material: StringName in drops:
			assert_true(cost_of_a_piece.has(material), "%s: %s is paid for" % [item, material])
			assert_lte(
				float(drops[material]), cost_of_a_piece[material], "%s: %s" % [item, material]
			)


func test_each_piece_is_put_down_outdoors_and_used_up() -> void:
	for item in PIECES:
		_world.remove_object(_tile)
		_state.player.inventory.add(item, 1)
		_hold(item)
		assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE, str(item))
		assert_eq(_world.object_at(_tile).type, PIECES[item])
		assert_eq(_count(item), 0)


func test_a_piece_is_not_put_down_on_water_or_an_occupied_tile() -> void:
	for item in PIECES:
		_state.player.inventory.add(item, 1)
		_hold(item)
		_world.set_terrain(_tile, Tile.Terrain.WATER)
		assert_ne(_state.use_facing_tile(), ToolUse.Use.PLACE, "%s on water" % item)
		_world.set_terrain(_tile, Tile.Terrain.GRASS)
		_place(WorldObjectTypes.CHEST)
		assert_ne(_state.use_facing_tile(), ToolUse.Use.PLACE, "%s on a chest" % item)
		_world.remove_object(_tile)


func test_a_placed_piece_joins_a_generated_run_and_stops_walking() -> void:
	for type in PIECES.values():
		_world.remove_object(_tile)
		_world.remove_object(_tile + Vector2i.RIGHT)
		var run_end := WorldObject.new(type, _tile + Vector2i.RIGHT)
		_world.add_object(run_end)
		var piece := _place(type)
		assert_eq(_world.connections(piece), 2, "%s joins east" % type)
		assert_eq(_world.connections(run_end), 8, "%s is joined from the west" % type)
		assert_false(_world.is_walkable(_tile))


func test_the_two_kinds_join_each_other() -> void:
	var wall := _place_beside(WorldObjectTypes.STONE_WALL)
	var fence := _place(WorldObjectTypes.WATTLE_FENCE)
	assert_eq(_world.connections(fence), 2)
	assert_eq(_world.connections(wall), 8)


func test_the_tool_takes_each_piece_down_for_what_it_cost() -> void:
	var tools := {
		WorldObjectTypes.WATTLE_FENCE: ItemTypes.AXE, WorldObjectTypes.STONE_WALL: ItemTypes.PICKAXE
	}
	var dropped := {
		WorldObjectTypes.WATTLE_FENCE: [ItemTypes.FIBRE, 2],
		WorldObjectTypes.STONE_WALL: [ItemTypes.STONE, 3],
	}
	for type in tools:
		_clear_ground()
		_place(type)
		_hit(tools[type], WorldObjectTypes.TYPES[type]["hp"])
		assert_null(_world.object_at(_tile), str(type))
		assert_eq(_dropped(dropped[type][0]), dropped[type][1], str(type))


func test_placed_pieces_are_kept_through_a_save() -> void:
	for type in PIECES.values():
		_world.remove_object(_tile)
		_place(type)
		assert_eq(_through_save().world.object_at(_tile).type, type)
