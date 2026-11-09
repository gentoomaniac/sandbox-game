extends GutTest
## Every picture under assets/ is imported and loads (see AssetCheck).


func test_every_picture_under_assets_loads() -> void:
	assert_eq(AssetCheck.missing(), [] as Array[String])


func test_every_item_and_object_has_its_pictures_in_both_art_sets() -> void:
	var problems := AssetCheck.catalog_problems(ItemTypes.TYPES, WorldObjectTypes.TYPES)
	assert_eq(problems, [] as Array[String])


func test_a_missing_picture_names_the_item_and_the_art_set() -> void:
	var items := {&"ghost": {"name": "Ghost"}}
	var problems := AssetCheck.catalog_problems(items, {})
	assert_eq(problems.size(), 4, "icon and ground picture, in two art sets")
	assert_eq(problems[0], "item ghost: no picture res://assets/items/ghost.png in the new art")
	assert_true(problems[3].ends_with("in the classic art"), problems[3])


func test_an_object_past_the_end_of_the_atlas_is_named() -> void:
	var objects := {
		&"far_post": {"atlas_row": 999, "variants": 1},
		&"blank": {"interior_sprite": "res://assets/interior/blank.png"},
	}
	var problems := AssetCheck.catalog_problems({}, objects)
	assert_has(problems, "object far_post: the new art atlas has no row 999 with its looks")
	assert_has(
		problems, "object blank: no picture res://assets/interior/blank.png in the classic art"
	)
