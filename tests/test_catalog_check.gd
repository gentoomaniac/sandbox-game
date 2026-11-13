extends GutTest
## CatalogCheck: the shared definitions are whole, and a mistake in small catalogs is named by
## its item or object and field.

const PLANK := {"name": "Plank", "description": "Wood.", "weight": 1.0, "stack_limit": 99}
const NO_PROBLEMS: Array[String] = []


func _item(overrides := {}) -> Dictionary:
	return PLANK.merged(overrides, true)


func _tool(overrides := {}) -> Dictionary:
	return {"tool": &"axe", "level": 1, "power": 1, "energy_factor": 1.0}.merged(overrides, true)


func _object(overrides := {}) -> Dictionary:
	return (
		{
			"footprint": Vector2i(1, 1),
			"blocks_walking": true,
			"harvest_level": 0,
			"atlas_row": 0,
			"variants": 1,
		}
		. merged(overrides, true)
	)


func _problems_of_item(overrides: Dictionary, objects := {}) -> Array[String]:
	return CatalogCheck.problems({&"plank": _item(overrides)}, objects)


func _problems_of_object(overrides: Dictionary, items := {}) -> Array[String]:
	return CatalogCheck.problems(items, {&"post": _object(overrides)})


func test_the_shared_catalogs_are_whole() -> void:
	assert_eq(CatalogCheck.problems(ItemTypes.TYPES, WorldObjectTypes.TYPES), NO_PROBLEMS)
	assert_eq(ItemTypes.build_problems, NO_PROBLEMS)
	assert_eq(WorldObjectTypes.build_problems, NO_PROBLEMS)


func test_a_whole_small_catalog_has_no_problems() -> void:
	assert_eq(_problems_of_item({}), NO_PROBLEMS)
	assert_eq(_problems_of_object({}), NO_PROBLEMS)


func test_a_problem_names_the_item_and_the_field() -> void:
	assert_eq(
		_problems_of_item({"stack_limit": 0}),
		["item plank: stack_limit must be a whole number, at least 1"]
	)
	assert_eq(
		_problems_of_item({"weight": -1.0}), ["item plank: weight must be a number, 0 or more"]
	)
	assert_eq(_problems_of_item({"name": ""}), ["item plank: name must be a text"])


func test_a_tool_needs_a_level_a_power_and_an_energy_factor() -> void:
	assert_eq(_problems_of_item(_tool({"level": 4})).size(), 1)
	assert_eq(_problems_of_item(_tool({"level": 3})), NO_PROBLEMS)
	assert_eq(_problems_of_item(_tool({"power": 0})).size(), 1)
	assert_eq(_problems_of_item(_tool({"energy_factor": 0.0})).size(), 1)
	assert_eq(_problems_of_item({"tool": &"axe", "level": 1}).size(), 2)


func test_a_wearable_stacks_one_and_has_a_slot() -> void:
	assert_eq(
		_problems_of_item({"equip_slot": Equipment.HEAD}),
		["item plank: a wearable has a stack_limit of 1"]
	)
	assert_eq(_problems_of_item({"equip_slot": &"tail", "stack_limit": 1}).size(), 1)


func test_what_an_item_places_or_plants_must_exist() -> void:
	assert_eq(
		_problems_of_item({"places": &"nowhere"}),
		["item plank: places is not an object type: nowhere"]
	)
	assert_eq(
		_problems_of_item({"plants": &"nowhere"}),
		["item plank: plants is not an object type: nowhere"]
	)


func test_what_an_item_places_says_where_and_has_the_picture_for_it() -> void:
	var objects := {&"post": _object()}
	assert_eq(_problems_of_item({"places": &"post"}, objects).size(), 1, "no placeable_in")
	objects[&"post"] = _object({"placeable_in": WorldObjectTypes.ANYWHERE})
	assert_eq(_problems_of_item({"places": &"post"}, objects).size(), 1, "inside needs a picture")
	objects[&"post"] = _object({"placeable_in": WorldObjectTypes.ANYWHERE, "interior_sprite": "x"})
	assert_eq(_problems_of_item({"places": &"post"}, objects), NO_PROBLEMS)


func test_two_items_cannot_place_the_same_object() -> void:
	var items := {&"a": _item({"places": &"post"}), &"b": _item({"places": &"post"})}
	var post := _object({"placeable_in": WorldObjectTypes.OUTDOORS})
	assert_eq(
		CatalogCheck.problems(items, {&"post": post}),
		["object post: is placed by more than one item: a, b"]
	)


func test_an_id_used_twice_is_named() -> void:
	var existing := {&"turnip": {}, &"oak": {}}
	assert_eq(CatalogCheck.reused_ids("item", existing, [&"kale", &"pea"]), NO_PROBLEMS)
	assert_eq(
		CatalogCheck.reused_ids("item", existing, [&"kale", &"turnip", &"kale"]),
		["item turnip: id is used twice", "item kale: id is used twice"]
	)
	assert_eq(
		CatalogCheck.reused_ids("object", existing, [&"oak"]), ["object oak: id is used twice"]
	)


func test_an_object_has_a_sane_footprint_and_harvest_level() -> void:
	assert_eq(
		_problems_of_object({"footprint": Vector2i(8, 1)}),
		["object post: footprint must be from 1x1 to 7x2 tiles"]
	)
	assert_eq(_problems_of_object({"footprint": Vector2i(0, 1)}).size(), 1)
	assert_eq(
		_problems_of_object({"harvest_level": 9}),
		["object post: harvest_level must be from 0 to 3"]
	)


func test_an_object_without_a_picture_is_named() -> void:
	var object := _object()
	object.erase("atlas_row")
	assert_eq(
		CatalogCheck.problems({}, {&"post": object}),
		["object post: has no picture: atlas_row, interior_sprite or sheet"]
	)


func test_what_an_object_drops_or_leaves_must_exist() -> void:
	assert_eq(
		_problems_of_object({"drops": {&"ghost": 1}}), ["object post: drops is not an item: ghost"]
	)
	assert_eq(
		_problems_of_object({"leaves": &"ghost"}),
		["object post: leaves is not an object type: ghost"]
	)
	assert_eq(_problems_of_object({"seed": &"ghost"}), ["object post: seed is not an item: ghost"])


func test_a_drop_count_is_a_whole_number_of_at_least_one() -> void:
	var items := {&"plank": _item()}
	assert_eq(
		_problems_of_object({"drops": {&"plank": 0}}, items),
		["object post: drops plank needs a whole number, at least 1"]
	)


func test_what_is_cut_down_needs_hit_points_and_the_tool_of_an_item() -> void:
	var axe := _item(_tool())
	assert_eq(_problems_of_object({"hp": 3, "tool": &"axe"}, {&"axe": axe}), NO_PROBLEMS)
	assert_eq(_problems_of_object({"hp": 3, "tool": &"axe"}).size(), 1, "no item is an axe")
	assert_eq(_problems_of_object({"hp": 0, "tool": &"axe"}, {&"axe": axe}).size(), 1)


func test_an_object_names_its_other_wrong_fields() -> void:
	assert_eq(
		_problems_of_object({"blocks_walking": 1}),
		["object post: blocks_walking must be true or false"]
	)
	assert_eq(
		_problems_of_object({"atlas_row": -1}), ["object post: atlas_row must be a row number"]
	)
	assert_eq(
		_problems_of_object({"variants": 0}),
		["object post: variants must be a whole number, at least 1"]
	)
	assert_eq(
		_problems_of_object({"seed_chance": 1.5}), ["object post: seed_chance must be from 0 to 1"]
	)
	assert_eq(
		_problems_of_object({"placed_on": []}),
		["object post: placed_on must be a list of at least one terrain"]
	)
	assert_eq(
		_problems_of_object({"matures_into": &"ghost"}),
		["object post: matures_into is not an object type: ghost"]
	)
	assert_eq(
		_problems_of_object({"produce": &"ghost"}), ["object post: produce is not an item: ghost"]
	)


func test_a_tree_the_item_plants_state_must_exist() -> void:
	var sapling := _object()
	var items := {
		&"acorn": _item({"plants": &"post", "plants_state": {"tree": &"ghost"}}),
	}
	assert_eq(
		CatalogCheck.problems(items, {&"post": sapling}),
		["item acorn: plants_state tree is not an object type: ghost"]
	)


func test_a_wearable_names_a_slot_that_exists() -> void:
	assert_eq(
		_problems_of_item({"equip_slot": &"tail", "stack_limit": 1}),
		["item plank: equip_slot is not an equipment slot: tail"]
	)
