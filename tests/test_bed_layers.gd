extends GutTest
## A bed lies under the player and its cover (the blanket) over them while they lie in it.

const KATE_MAP := "res://maps/interiors/kate.tmx"

var _view: InteriorView
var _bed: WorldObject


func before_each() -> void:
	_view = InteriorView.new()
	add_child_autofree(_view)
	var interior := InteriorLoader.load_interior(KATE_MAP)
	_view.show_interior(interior)
	_bed = interior.object_at(Vector2i(1, 2))


func _covers() -> Array[Sprite2D]:
	var covers: Array[Sprite2D] = []
	for node in _view.get_node("Beds").get_children():
		if node.z_index == PlayerView.COVER_Z_INDEX:
			covers.append(node)
	return covers


func test_the_bed_is_drawn_under_the_entities_that_stand_in_the_room() -> void:
	var beds := _view.get_node("Beds")
	assert_gt(beds.get_index(), _view.get_node("Ground").get_index())
	assert_lt(beds.get_index(), _view.entities.get_index())
	assert_eq(beds.get_child_count(), 2, "the bed and its cover")


func test_the_cover_shows_only_while_the_player_lies_in_the_bed() -> void:
	var covers := _covers()
	assert_eq(covers.size(), 1)
	assert_false(covers[0].visible)
	_view.cover_bed(_bed)
	assert_true(covers[0].visible)
	_view.cover_bed(null)
	assert_false(covers[0].visible)


func test_the_cover_is_above_the_player_lying_in_the_bed() -> void:
	assert_gt(PlayerView.COVER_Z_INDEX, PlayerView.LYING_Z_INDEX)


func test_every_bed_has_a_head_end_the_player_can_lie_with() -> void:
	for type: StringName in WorldObjectTypes.TYPES:
		var data: Dictionary = WorldObjectTypes.TYPES[type]
		if data.has("bed"):
			assert_true(PlayerView.LYING_POSES.has(data["bed"]), type)


func test_every_bed_in_a_house_has_a_cover_of_the_size_of_its_picture() -> void:
	for type: StringName in WorldObjectTypes.TYPES:
		var data: Dictionary = WorldObjectTypes.TYPES[type]
		# What is `outdoors_only` has an interior picture only for its ghost.
		var is_in_houses: bool = (
			data.has("interior_sprite") and not data.get("outdoors_only", false)
		)
		if not data.has("bed") or not is_in_houses:
			continue
		assert_true(data.has("interior_cover"), type)
		var picture: Texture2D = load(data["interior_sprite"])
		var cover: Texture2D = load(data["interior_cover"])
		assert_eq(cover.get_size(), picture.get_size(), type)


func test_the_bedroll_has_a_cover_of_the_size_of_its_atlas_cell() -> void:
	var cover: Texture2D = load(
		WorldObjectTypes.TYPES[WorldObjectTypes.SLEEPING_BAG]["object_cover"]
	)
	assert_eq(cover.get_size(), Vector2(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT))


func test_the_object_cover_shows_over_the_bedroll_the_player_lies_in() -> void:
	var cover := ObjectCover.new()
	add_child_autofree(cover)
	var bedroll := WorldObject.new(WorldObjectTypes.SLEEPING_BAG, Vector2i(3, 5))
	cover.cover(bedroll)
	assert_true(cover.visible)
	assert_eq(cover.z_index, PlayerView.COVER_Z_INDEX)
	assert_eq(cover.position.x, 3.5 * TerrainTileset.TILE_SIZE)
	assert_eq(cover.position.y + ObjectTileset.CELL_HEIGHT / 2.0, 7.0 * TerrainTileset.TILE_SIZE)
	cover.cover(null)
	assert_false(cover.visible)
	cover.cover(_bed)
	assert_false(cover.visible, "a bed of a house has its cover in the room")


func test_the_classic_bedroll_has_its_own_cover() -> void:
	var path: String = WorldObjectTypes.TYPES[WorldObjectTypes.SLEEPING_BAG]["object_cover"]
	ArtSet.is_classic = true
	var classic := ArtSet.path(path)
	ArtSet.is_classic = false
	assert_eq(classic, "res://assets/classic/bedroll_cover.png")
	assert_eq(load(classic).get_size(), load(path).get_size())
