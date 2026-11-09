extends GutTest
## What the catalogs of items and objects hand out can't be changed by the caller.


func test_an_item_type_cannot_be_changed_through_what_the_catalog_returns() -> void:
	assert_true(ItemTypes.TYPES.is_read_only())
	assert_true(ItemTypes.TYPES[ItemTypes.TURNIP].is_read_only())


func test_an_object_type_cannot_be_changed_down_to_its_lists() -> void:
	assert_true(WorldObjectTypes.TYPES.is_read_only())
	var jetty: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.JETTY]
	assert_true(jetty.is_read_only())
	assert_true(jetty["placed_on"].is_read_only())


func test_the_trunks_and_crops_made_at_start_are_read_only_too() -> void:
	var trunk_type := WorldObjectTypes.trunk_type(WorldObjectTypes.OAK, false)
	assert_true(WorldObjectTypes.TYPES[trunk_type]["drops"].is_read_only())
	assert_true(WorldObjectTypes.TYPES[WorldObjectTypes.TURNIP].is_read_only())
