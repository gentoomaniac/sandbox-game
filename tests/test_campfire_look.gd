extends GutTest
## A campfire that is out is drawn as one: its own picture in the atlas row (after the burning one),
## and without the flames that the shader plays over the burning one (task 56).


func _fireplace() -> WorldObject:
	return WorldObject.new(WorldObjectTypes.FIREPLACE, Vector2i(3, 4))


func test_a_burning_fire_has_the_first_picture_and_one_that_is_out_the_second() -> void:
	var fire := _fireplace()
	fire.storage.add(ItemTypes.LOGS, 1)
	assert_eq(ObjectTileset.atlas_cell(fire).x, 1, "out")
	Campfire.ignite(fire)
	assert_eq(ObjectTileset.atlas_cell(fire).x, 0, "burning")


func test_the_fireplace_has_two_pictures_in_its_row() -> void:
	assert_eq(ObjectTileset.looks_count(WorldObjectTypes.TYPES[WorldObjectTypes.FIREPLACE]), 2)


func test_the_flames_play_over_the_burning_picture_only() -> void:
	var tileset := ObjectTileset.new(CropRules.default_rules(), AmbientMotion.new())
	var source: TileSetAtlasSource = tileset.tile_set.get_source(SeasonBlend.Look.SPRING)
	var row: int = WorldObjectTypes.TYPES[WorldObjectTypes.FIREPLACE]["atlas_row"]
	assert_not_null(source.get_tile_data(Vector2i(0, row), 0).material, "burning")
	assert_null(source.get_tile_data(Vector2i(1, row), 0).material, "out")
