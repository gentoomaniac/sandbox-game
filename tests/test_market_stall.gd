extends ResourceCase
## The market stall of the town square (issue #10): an object of the catalogue that is solid on
## both its tiles and that nobody can take down, which no item places. Its pictures in both art
## sets are checked with all the others (see test_asset_check).


func test_the_stall_is_in_the_catalogue() -> void:
	assert_has(WorldObjectTypes.TYPES, WorldObjectTypes.MARKET_STALL)
	assert_eq(CatalogCheck.problems(ItemTypes.TYPES, WorldObjectTypes.TYPES), [] as Array[String])
	assert_eq(WorldObjectTypes.build_problems, [] as Array[String])


func test_both_tiles_of_the_stall_are_solid() -> void:
	_make_room()
	_world.add_object(WorldObject.new(WorldObjectTypes.MARKET_STALL, _tile))
	assert_false(_world.is_walkable(_tile))
	assert_false(_world.is_walkable(_tile + Vector2i.RIGHT))
	assert_true(_world.is_walkable(_tile + Vector2i.LEFT))


func test_the_stall_has_no_item_and_cannot_be_hit_down() -> void:
	var stall: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.MARKET_STALL]
	assert_false(stall.has("hp"))
	assert_false(stall.has("drops"))
	assert_false(stall.has("placeable_in"))
