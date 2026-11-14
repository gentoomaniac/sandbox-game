extends TravelMaskCase
## The cache of the masks: asking, making on the worker, following the edits, and the limits.


func before_each() -> void:
	super()
	load_chunk_and_neighbours(COAST)


func test_a_mask_is_asked_for_and_there_when_its_chunks_are_generated() -> void:
	assert_null(masks.mask_of(COAST), "not at once")
	assert_not_null(masks.wait_for_mask(COAST))
	assert_not_null(masks.mask_of(COAST), "and it is kept")
	assert_eq(masks.raw_chunk_coords().size(), 4, "its own chunk and the three before it")


func test_the_chunk_made_on_the_worker_is_the_one_the_main_thread_makes() -> void:
	masks.wait_for_mask(COAST)
	var raw := masks.raw_chunk(COAST)
	var loaded := world.chunk_at(COAST)
	assert_eq(raw.objects().size(), loaded.objects().size())
	for object in loaded.objects():
		var made := raw.object_at(Chunk.local_pos(object.pos))
		assert_true(
			made != null and made.type == object.type, "%s at %s" % [object.type, object.pos]
		)
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var local := Vector2i(x, y)
			assert_eq(raw.terrain_at(local), loaded.terrain_at(local))


func test_making_masks_changes_nothing_in_the_world() -> void:
	var loaded := world.loaded_chunk_coords()
	var changes := world.change_count
	masks.wait_for_mask(COAST)
	masks.wait_for_mask(MUD)
	assert_eq(world.loaded_chunk_coords(), loaded)
	assert_eq(world.change_count, changes)
	assert_eq(world.edited_objects().size(), 0)
	assert_eq(world.tilled_tiles().size(), 0)


func test_the_raw_chunks_follow_edits_made_after_they_were_generated() -> void:
	masks.wait_for_mask(COAST)
	var willow := find_object(COAST, WorldObjectTypes.WILLOW)
	var tile := empty_row(COAST, Tile.Terrain.GRASS)
	world.take_off(willow)
	world.add_object(WorldObject.new(WorldObjectTypes.PEN_FENCE, tile))
	assert_false(masks.mask_coords().has(COAST), "the mask is dropped")
	assert_not_null(masks.raw_chunk(COAST), "the generated chunk is not")
	assert_true(mask_is_free(willow.pos))
	assert_false(mask_is_free(tile))
	assert_parity(COAST)
	assert_not_null(masks.raw_chunk(COAST).object_at(Chunk.local_pos(willow.pos)), "no edit in it")


func test_an_edit_drops_the_masks_of_its_chunk_and_the_three_it_reaches_into() -> void:
	var edited := COAST
	for y in range(-1, 3):
		for x in range(-1, 3):
			masks.wait_for_mask(edited + Vector2i(x, y))
	var before := masks.mask_coords().size()
	world.take_off(find_object(edited, WorldObjectTypes.WILLOW))
	var dropped := [edited, edited + Vector2i.RIGHT, edited + Vector2i.DOWN, edited + Vector2i.ONE]
	assert_eq(masks.mask_coords().size(), before - 4)
	for coords in dropped:
		assert_false(masks.mask_coords().has(coords), "%s" % coords)


func test_an_edit_made_while_a_mask_waits_for_its_chunks_is_in_the_mask() -> void:
	assert_null(masks.mask_of(COAST))
	var willow := find_object(COAST, WorldObjectTypes.WILLOW)
	world.take_off(willow)
	assert_true(mask_is_free(willow.pos))
	assert_parity(COAST)


func test_one_mask_is_stamped_in_an_update() -> void:
	load_chunk_and_neighbours(COAST + Vector2i.RIGHT)
	for x in 3:
		masks.wait_for_mask(COAST + Vector2i(x, 0))
	world.take_off(find_object(COAST, WorldObjectTypes.WILLOW))
	world.take_off(find_object(COAST + Vector2i.RIGHT, WorldObjectTypes.KNICK))
	for x in 3:
		masks.mask_of(COAST + Vector2i(x, 0))
	masks.update()
	assert_eq(masks.mask_coords().size(), 1)
	masks.update()
	assert_eq(masks.mask_coords().size(), 2)


func test_the_least_recently_used_masks_and_chunks_go() -> void:
	masks = TravelMasks.new(world, 2, 4)
	masks.wait_for_mask(COAST)
	masks.wait_for_mask(COAST + Vector2i.RIGHT)
	masks.mask_of(COAST)
	masks.wait_for_mask(COAST + Vector2i(2, 0))
	assert_true(masks.mask_coords().has(COAST), "used last but one")
	assert_false(masks.mask_coords().has(COAST + Vector2i.RIGHT), "unused")
	assert_true(masks.mask_coords().has(COAST + Vector2i(2, 0)))
	assert_eq(masks.raw_chunk_coords().size(), 4)


func test_the_limits_are_the_rules_numbers() -> void:
	var values := DataFile.read_sections(NpcRules.DEFAULT_PATH)
	values["travel"]["far_masks_kept"] = 2
	values["travel"]["far_chunks_kept"] = 4
	masks = TravelMasks.for_world(world, NpcRules.new(values))
	for x in 4:
		masks.wait_for_mask(COAST + Vector2i(x, 0))
	assert_eq(masks.mask_coords().size(), 2)
	assert_eq(masks.raw_chunk_coords().size(), 4)
