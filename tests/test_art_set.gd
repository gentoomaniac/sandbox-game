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


func test_the_classic_buildings_are_as_big_as_the_new() -> void:
	ArtSet.is_classic = true
	for building_id in BuildingTypes.ids():
		var path: String = BuildingTypes.TYPES[building_id]["sprite"]
		var classic: Texture2D = load(ArtSet.path(path))
		assert_ne(classic.resource_path, path, "%s has classic art" % building_id)
		assert_eq(classic.get_size(), load(path).get_size(), path)


func test_the_classic_crops_are_as_big_as_the_new() -> void:
	ArtSet.is_classic = true
	var rules := CropRules.default_rules()
	for crop_id in rules.crop_ids():
		var path: String = rules.crop(crop_id)["sheet"]
		var classic: Texture2D = load(ArtSet.path(path))
		# The Geest grains were first drawn at 32 px.
		var has_classic_art := crop_id not in [&"rye", &"buckwheat"]
		assert_eq(classic.resource_path != path, has_classic_art, str(crop_id))
		assert_eq(classic.get_size(), load(path).get_size(), path)


func test_the_crops_follow_the_art_set_and_sway_on_its_pixels() -> void:
	var tileset := ObjectTileset.new(CropRules.default_rules(), AmbientMotion.new())
	var source: TileSetAtlasSource = tileset.tile_set.get_source(
		tileset.crop_source_id(WorldObjectTypes.TURNIP)
	)
	ArtSet.is_classic = true
	tileset.show_art_set()
	assert_eq(source.texture.resource_path, "res://assets/classic/crops/turnip.png")
	var material := source.get_tile_data(Vector2i.ZERO, 0).material as ShaderMaterial
	assert_eq(material.get_shader_parameter("art_scale"), float(TerrainTileset.ART_16_SCALE))
	ArtSet.is_classic = false
	tileset.show_art_set()
	assert_eq(source.texture.resource_path, "res://assets/crops/turnip.png")
	material = source.get_tile_data(Vector2i.ZERO, 0).material as ShaderMaterial
	assert_eq(material.get_shader_parameter("art_scale"), 1.0)


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


func test_the_classic_object_atlases_have_the_cells_of_the_new() -> void:
	var cell_size := Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
	for look: SeasonBlend.Look in SeasonBlend.Look.values():
		var path := SeasonalArt.path(ObjectTileset.ATLAS_PATH, look)
		var classic := path.replace("res://assets/", ArtSet.CLASSIC_DIR)
		assert_eq(
			_drawn_pictures(_drawn_cells(load(classic).get_image(), cell_size)),
			_drawn_pictures(_drawn_cells(load(path).get_image(), cell_size)),
			path
		)


## The pictures of the object atlas that the drawn `cells` belong to, by their first cell: a
## picture `cells_wide` cells wide counts once (the classic Ewer fills only its middle cell).
func _drawn_pictures(cells: Array[Vector2i]) -> Array[Vector2i]:
	var cells_wide := {}
	for object_type: Dictionary in WorldObjectTypes.TYPES.values():
		if object_type.has("cells_wide"):
			cells_wide[object_type["atlas_row"]] = object_type["cells_wide"]
	var pictures: Array[Vector2i] = []
	for cell in cells:
		var width: int = cells_wide.get(cell.y, 1)
		var picture := Vector2i(cell.x - cell.x % width, cell.y)
		if not pictures.has(picture):
			pictures.append(picture)
	return pictures


func test_the_object_atlases_follow_the_art_set() -> void:
	var tileset := ObjectTileset.new()
	var snow: TileSetAtlasSource = tileset.tile_set.get_source(SeasonBlend.Look.SNOW)
	ArtSet.is_classic = true
	tileset.show_art_set()
	assert_eq(snow.texture.resource_path, "res://assets/classic/objects_snow.png")
	ArtSet.is_classic = false
	tileset.show_art_set()
	assert_eq(snow.texture.resource_path, "res://assets/objects_snow.png")


func test_the_ground_moves_on_the_pixels_of_its_art_in_either_set() -> void:
	var motion := AmbientMotion.new()
	assert_eq(motion.water.get_shader_parameter("art_scale"), 1.0, "drawn at 32 px")
	ArtSet.is_classic = true
	motion.show_art_set()
	for material in [motion.water, motion.mud, motion.decoration_sway, motion.lily_pads]:
		assert_eq(material.get_shader_parameter("art_scale"), 2.0, "the classic 16 px art")


func test_the_plants_sway_on_the_pixels_of_their_art_in_either_set() -> void:
	var motion := AmbientMotion.new()
	var oak := motion.object_material(WorldObjectTypes.OAK)
	var profile: Dictionary = AmbientMotion.SWAY_PROFILES[WorldObjectTypes.OAK]
	assert_eq(oak.get_shader_parameter("art_scale"), 1.0, "drawn at 32 px")
	assert_eq(oak.get_shader_parameter("top"), profile["top"])
	assert_eq(
		oak.get_shader_parameter("cell_size"),
		Vector2(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
	)
	ArtSet.is_classic = true
	motion.show_art_set()
	assert_eq(oak.get_shader_parameter("art_scale"), 2.0, "the classic 16 px art")
	assert_eq(oak.get_shader_parameter("top"), profile["top"] / 2.0, "in the classic art's pixels")


## The atlas cells of an image that have a pixel drawn, cells of `size` (a tile by default).
func _drawn_cells(
	image: Image, size := Vector2i(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE)
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in image.get_height() / size.y:
		for column in image.get_width() / size.x:
			if not image.get_region(Rect2i(Vector2i(column, row) * size, size)).is_invisible():
				cells.append(Vector2i(column, row))
	return cells


func test_the_classic_interior_is_as_big_as_the_new() -> void:
	ArtSet.is_classic = true
	var paths: Array[String] = [InteriorView.ATLAS_PATH]
	for type: StringName in WorldObjectTypes.TYPES:
		var data: Dictionary = WorldObjectTypes.TYPES[type]
		for key in ["interior_sprite", "interior_cover"]:
			if data.has(key):
				paths.append(data[key])
	for path in paths:
		assert_eq(load(ArtSet.path(path)).get_size(), load(path).get_size(), path)
	assert_ne(ArtSet.path(InteriorView.ATLAS_PATH), InteriorView.ATLAS_PATH, "classic art")


func test_a_room_shown_switches_its_tiles_and_furniture_with_the_art() -> void:
	var view := InteriorView.new()
	add_child_autofree(view)
	view.show_interior(InteriorLoader.load_interior("res://maps/interiors/kate.tmx"))
	ArtSet.show(true, get_tree())
	var atlas: TileSetAtlasSource = view.get_node("Ground").tile_set.get_source(
		InteriorView.SOURCE_ID
	)
	assert_eq(atlas.texture.resource_path, "res://assets/classic/interior.png")
	# The bed, the first of the sprites shown anew.
	var beds := view.get_node("Beds").get_children()
	var bed: Sprite2D = beds.filter(_is_kept)[0]
	assert_eq(bed.texture.resource_path, "res://assets/classic/interior/bed.png")
	ArtSet.show(false, get_tree())
	assert_eq(atlas.texture.resource_path, InteriorView.ATLAS_PATH)


func _is_kept(node: Node) -> bool:
	return not node.is_queued_for_deletion()


func test_every_item_has_a_classic_icon_and_ground_item_as_big_as_the_new() -> void:
	ArtSet.is_classic = true
	for item: StringName in ItemTypes.TYPES:
		# The pancakes were first drawn at 32 px.
		var has_classic_art := item != ItemTypes.BUCKWHEAT_PANCAKES
		var icon := ItemTypes.icon_path(item)
		assert_eq(ArtSet.path(icon) != icon, has_classic_art, "%s has a classic icon" % item)
		var ground := ItemTypes.ground_icon_path(item)
		assert_eq(ArtSet.path(ground) != ground, has_classic_art, "%s has classic art" % item)
		assert_eq(load(ArtSet.path(ground)).get_size(), load(ground).get_size(), ground)


func test_a_slot_shown_switches_its_icon_with_the_art() -> void:
	var slot := SlotView.new()
	add_child_autofree(slot)
	slot.show_stack({"item": ItemTypes.AXE, "count": 1}, false)
	ArtSet.show(true, get_tree())
	assert_eq(slot._icon.resource_path, "res://assets/classic/items/axe.png")
	ArtSet.show(false, get_tree())
	assert_eq(slot._icon.resource_path, "res://assets/items/axe.png")


func test_an_icon_held_by_the_mouse_switches_with_the_art() -> void:
	var icon := ItemIcon.new()
	add_child_autofree(icon)
	icon.show_item(ItemTypes.AXE)
	ArtSet.show(true, get_tree())
	assert_eq(icon.texture.resource_path, "res://assets/classic/items/axe.png")
	ArtSet.show(false, get_tree())
	assert_eq(icon.texture.resource_path, "res://assets/items/axe.png")
