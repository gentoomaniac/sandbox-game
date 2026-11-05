extends GutTest
## The object atlas and the types that describe it agree.


## The height in pixels from the lowest row of a cell to its highest opaque one.
func _opaque_height(image: Image, atlas_cell: Vector2i) -> int:
	var cell_origin := atlas_cell * Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
	for y in ObjectTileset.CELL_HEIGHT:
		for x in ObjectTileset.CELL_WIDTH:
			if image.get_pixelv(cell_origin + Vector2i(x, y)).a > 0.0:
				return ObjectTileset.CELL_HEIGHT - y
	return 0


func test_sprite_height_is_at_least_the_opaque_height_of_every_variant() -> void:
	var image: Image = load(ObjectTileset.ATLAS_PATH).get_image()
	for type_name: StringName in WorldObjectTypes.TYPES:
		var object_type: Dictionary = WorldObjectTypes.TYPES[type_name]
		if not object_type.has("sprite_height"):
			continue
		for variant in ObjectTileset.looks_count(object_type):
			var opaque := _opaque_height(image, Vector2i(variant, object_type["atlas_row"]))
			assert_gte(object_type["sprite_height"], opaque, "%s variant %d" % [type_name, variant])


func test_the_dead_stump_has_its_own_row_with_both_variants_drawn_in_every_look() -> void:
	var dead_stump: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.DEAD_STUMP]
	var rows: Array = []
	for object_type: Dictionary in WorldObjectTypes.TYPES.values():
		rows.append(object_type.get("atlas_row"))
	assert_eq(rows.count(dead_stump["atlas_row"]), 1, "nothing else on its row")
	assert_eq(dead_stump["variants"], 2)
	for look in SeasonBlend.Look.values():
		var image: Image = load(SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)).get_image()
		for variant in dead_stump["variants"]:
			var opaque := _opaque_height(image, Vector2i(variant, dead_stump["atlas_row"]))
			assert_gt(opaque, 0, "look %d variant %d" % [look, variant])


func test_every_variant_has_something_drawn() -> void:
	var image: Image = load(ObjectTileset.ATLAS_PATH).get_image()
	for type_name: StringName in WorldObjectTypes.TYPES:
		var object_type: Dictionary = WorldObjectTypes.TYPES[type_name]
		if not object_type.has("atlas_row"):
			continue
		for variant in ObjectTileset.looks_count(object_type):
			var opaque := _opaque_height(image, Vector2i(variant, object_type["atlas_row"]))
			assert_gt(opaque, 0, "%s variant %d" % [type_name, variant])
