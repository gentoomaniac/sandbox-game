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


func test_every_variant_has_something_drawn() -> void:
	var image: Image = load(ObjectTileset.ATLAS_PATH).get_image()
	for type_name: StringName in WorldObjectTypes.TYPES:
		var object_type: Dictionary = WorldObjectTypes.TYPES[type_name]
		if not object_type.has("atlas_row"):
			continue
		for variant in ObjectTileset.looks_count(object_type):
			var opaque := _opaque_height(image, Vector2i(variant, object_type["atlas_row"]))
			assert_gt(opaque, 0, "%s variant %d" % [type_name, variant])
