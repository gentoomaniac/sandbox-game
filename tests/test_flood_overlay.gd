extends GutTest
## The picture of the storm surge's water (FloodMask and FloodOverlay, #103): a mask per chunk, made
## again only for the chunks whose tiles change.

var _world: World
var _residency: ChunkResidency
var _overlay: FloodOverlay


func before_each() -> void:
	_world = CoastWorld.make()
	_residency = ChunkResidency.new(_world)
	_overlay = FloodOverlay.new(ShaderMaterial.new())
	add_child_autofree(_overlay)
	_overlay.show_world(_world, _residency)


func _sprites() -> Array[Node]:
	return _overlay.get_children()


func test_the_mask_has_the_depth_of_each_wet_tile_in_centimetres() -> void:
	var tile := Vector2i(-300, 5)
	_world.flood._set_depth(tile, 130)
	_world.flood._set_depth(tile + Vector2i(1, 0), 900)
	var image := FloodMask.image_of(_world.flood, Chunk.world_to_chunk(tile))
	var local := Chunk.local_pos(tile)
	assert_eq(image.get_pixel(local.x, local.y).r8, 130)
	assert_eq(image.get_pixel(local.x + 1, local.y).r8, FloodMask.MAX_DEPTH_CM, "deep is capped")
	assert_eq(image.get_pixel(local.x, local.y + 1).r8, 0, "dry")


func test_a_chunk_with_water_gets_a_sprite_and_a_dry_one_none() -> void:
	assert_eq(_sprites().size(), 0)
	_world.flood.begin(_world, 3.4, 1000, 1)
	_world.flood.step_tiles(_world, 200)
	var wet_chunks := 0
	for coords in _world.loaded_chunk_coords():
		wet_chunks += int(not _world.flood.wet_in_chunk(coords).is_empty())
	assert_gt(wet_chunks, 0)
	assert_eq(_sprites().size(), wet_chunks)


func test_a_chunk_that_dries_loses_its_sprite() -> void:
	_world.flood.begin(_world, 3.4, 1000, 1)
	_world.flood.settle(_world)
	assert_gt(_sprites().size(), 0)
	_world.flood.advance(_world, _world.flood.drain_minute, false)
	_world.flood.settle(_world)
	await wait_frames(1)
	assert_eq(_sprites().size(), 0)
