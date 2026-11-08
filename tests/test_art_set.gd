extends GutTest
## The art sets: which picture is loaded in each, and the switch of the views that keep theirs.

const BODY := "res://assets/character/body_0.png"
## Drawn after the people went native, so it has no classic picture.
const TRICORNE := "res://assets/character/head_tricorne.png"


func after_each() -> void:
	ArtSet.is_classic = false


func test_the_new_art_is_the_picture_itself() -> void:
	assert_eq(ArtSet.path(BODY), BODY)


func test_the_classic_art_is_the_picture_under_classic() -> void:
	ArtSet.is_classic = true
	assert_eq(ArtSet.path(BODY), "res://assets/classic/character/body_0.png")


func test_a_picture_without_classic_art_is_the_new_one_in_both_sets() -> void:
	ArtSet.is_classic = true
	assert_eq(ArtSet.path(TRICORNE), TRICORNE)


func test_the_classic_art_has_the_cells_of_the_new() -> void:
	ArtSet.is_classic = true
	for path in [BODY, "res://assets/character/collapse/body_0.png"]:
		var classic: Texture2D = load(ArtSet.path(path))
		assert_eq(classic.get_size(), load(path).get_size(), path)


func test_a_villager_shown_switches_its_sheets_with_the_art() -> void:
	var look := Appearance.new()
	look.wear(Appearance.HEAD, "tricorne")
	var view := NpcView.new(Npc.new("Hinnerk", &"male", look, Vector2.ZERO))
	add_child_autofree(view)
	ArtSet.show(true, get_tree())
	var sheets := view.get_children().map(
		func(sprite: Sprite2D) -> String: return sprite.texture.resource_path
	)
	assert_eq(
		sheets,
		[
			"res://assets/classic/character/body_0.png",
			"res://assets/classic/character/hair_0.png",
			TRICORNE,
		]
	)
	ArtSet.show(false, get_tree())
	assert_eq(view.get_child(0).texture.resource_path, BODY)


func test_the_classic_atlases_have_the_tiles_of_the_new() -> void:
	for look: SeasonBlend.Look in SeasonBlend.GROUND_LOOKS:
		for atlas in [TerrainTileset.TERRAIN_ATLAS_PATH, TerrainTileset.DECORATION_ATLAS_PATH]:
			var path := SeasonalArt.path(atlas, look)
			var new_cells := _drawn_cells(load(path).get_image())
			var classic_cells := _drawn_cells(
				load(path.replace("res://assets/", ArtSet.CLASSIC_DIR)).get_image()
			)
			assert_eq(classic_cells, new_cells, path)


func test_the_atlases_follow_the_art_set() -> void:
	var tileset := TerrainTileset.new()
	var summer: TileSetAtlasSource = tileset.tile_set.get_source(
		TerrainTileset.terrain_source_id(SeasonBlend.Look.SUMMER)
	)
	ArtSet.is_classic = true
	tileset.show_art_set()
	assert_eq(summer.texture.resource_path, "res://assets/classic/terrain.png")
	ArtSet.is_classic = false
	tileset.show_art_set()
	assert_eq(summer.texture.resource_path, TerrainTileset.TERRAIN_ATLAS_PATH)


func test_the_ground_moves_on_the_pixels_of_its_art_in_either_set() -> void:
	var motion := AmbientMotion.new()
	assert_eq(motion.water.get_shader_parameter("art_scale"), 1.0, "drawn at 32 px")
	assert_eq(motion.flower_sway.get_shader_parameter("art_scale"), 2.0, "still 16 px art")
	ArtSet.is_classic = true
	motion.show_art_set()
	for material in [motion.water, motion.mud, motion.decoration_sway, motion.lily_pads]:
		assert_eq(material.get_shader_parameter("art_scale"), 2.0, "the classic 16 px art")


## The atlas cells of an image that have a pixel drawn.
func _drawn_cells(image: Image) -> Array[Vector2i]:
	var size := TerrainTileset.TILE_SIZE
	var cells: Array[Vector2i] = []
	for row in image.get_height() / size:
		for column in image.get_width() / size:
			if not image.get_region(Rect2i(column * size, row * size, size, size)).is_invisible():
				cells.append(Vector2i(column, row))
	return cells
