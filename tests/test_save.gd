extends GutTest
## Saving: every class writes itself to plain JSON values and reads itself back.

const SEED := 7
const SAVE_DIR := "user://test_saves"
const SAVE_PATH := SAVE_DIR + "/world.json"

var _state: GameState
var _tilled_tile: Vector2i


func before_each() -> void:
	_state = GameState.new_game(SEED)


func after_each() -> void:
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR.path_join(file_name))


## Through real JSON text, so a value JSON can't keep (an int, a Vector2i) fails the test.
func _through_json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func _free_tiles_near_player(count: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var around := _state.player.tile()
	for y in range(-8, 9):
		for x in range(-8, 9):
			var pos := around + Vector2i(x, y)
			if _state.world.is_free_on(pos, Tile.Terrain.GRASS) and tiles.size() < count:
				tiles.append(pos)
	return tiles


func _place_house() -> Building:
	var around := _state.player.tile()
	for y in range(-12, 13):
		for x in range(-12, 13):
			var house := _state.world.place_building(
				BuildingTypes.SMALL_HOUSE, around + Vector2i(x, y)
			)
			if house != null:
				return house
	fail_test("no room for a house")
	return null


## A game with edits of every kind: tilled soil, a growing crop, a removed tree, and a house
## the player has been in and slept in, standing inside it.
func _lived_in_state() -> GameState:
	var tiles := _free_tiles_near_player(2)
	_tilled_tile = tiles[0]
	_state.world.set_terrain(tiles[0], Tile.Terrain.SOIL)
	_state.world.set_terrain(tiles[1], Tile.Terrain.SOIL)
	_state.world.add_object(WorldObject.new(GameState.CROP, tiles[1]))
	_state.clock.advance(GameClock.MINUTES_PER_DAY)
	_state.player.inventory.add(ItemTypes.TURNIP, 3)
	_state.player.inventory.select(4)
	var house := _place_house()
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	_state.player.position = Vector2(2.5, 3.5)
	_state.sleep_in(_bed_in(house.interior))
	return _state


func _bed_in(interior: Interior) -> WorldObject:
	for object in interior.objects():
		if object.sleep_minutes() > 0:
			return object
	fail_test("no bed in the interior")
	return null


## Streaming, as the game does it: generates the chunks `loaded` has, edits replayed on top.
func _load_chunks_like(loaded: World, target: World) -> void:
	var generator := WorldGenerator.new(SEED)
	for coords in loaded.loaded_chunk_coords():
		target.add_chunk(generator.generate_chunk(coords))


func _crop_in(world: World) -> WorldObject:
	for coords in world.loaded_chunk_coords():
		for object in world.chunk_at(coords).objects():
			if object.is_crop():
				return object
	return null


func _remove_a_tree() -> Vector2i:
	for coords in _state.world.loaded_chunk_coords():
		for object in _state.world.chunk_at(coords).objects():
			if object.type == WorldObjectTypes.OAK:
				_state.world.remove_object(object.pos)
				return object.pos
	fail_test("no tree to remove")
	return Vector2i.ZERO


func test_world_object_round_trip_keeps_its_growth() -> void:
	var crop := WorldObject.new(GameState.CROP, Vector2i(-3, 4))
	crop.grow_one_day()
	var restored := WorldObject.from_dict(_through_json(crop.to_dict()))
	assert_eq(restored.type, crop.type)
	assert_eq(restored.pos, Vector2i(-3, 4))
	assert_eq(restored.days_grown(), 1)


func test_clock_round_trip() -> void:
	_state.clock.advance(GameClock.MINUTES_PER_DAY + 95)
	var restored := GameClock.from_dict(_through_json(_state.clock.to_dict()))
	assert_eq(restored.day, 2)
	assert_eq(restored.minute_of_day, _state.clock.minute_of_day)


func test_appearance_round_trip_keeps_the_layer_order() -> void:
	var appearance := Appearance.new()
	appearance.wear(Appearance.HAIR, "2")
	appearance.take_off(Appearance.HELD)
	var restored := Appearance.from_dict(_through_json(appearance.to_dict()))
	assert_eq(restored.layers, appearance.layers)
	assert_eq(restored.layers[0].slot, Appearance.BODY)


func test_player_round_trip() -> void:
	var player := _state.player
	player.position = Vector2(12.25, -3.75)
	player.facing = Vector2i.LEFT
	var restored := PlayerState.from_dict(_through_json(player.to_dict()), _state.world)
	assert_eq(restored.position, player.position)
	assert_eq(restored.facing, Vector2i.LEFT)
	assert_eq(restored.home_bed, player.home_bed)
	assert_eq(restored.home_map, _state.world)


func test_interior_round_trip() -> void:
	var interior := InteriorLoader.load_interior(
		BuildingTypes.TYPES[BuildingTypes.SMALL_HOUSE]["interior_map"]
	)
	var restored := Interior.from_dict(_through_json(interior.to_dict()))
	assert_eq(restored.to_dict(), interior.to_dict())
	assert_eq(restored.exit_tile, interior.exit_tile)
	assert_eq(restored.objects().size(), interior.objects().size())
	assert_eq(restored.is_walkable(interior.entry_tile()), true)


func test_building_without_an_interior_round_trip() -> void:
	var building := Building.new(BuildingTypes.SMALL_HOUSE, Vector2i(5, -6))
	var restored := Building.from_dict(_through_json(building.to_dict()))
	assert_eq(restored.origin, building.origin)
	assert_eq(restored.type, building.type)
	assert_null(restored.interior)


func test_a_new_game_round_trip() -> void:
	var data := _through_json(_state.to_dict())
	assert_eq(_through_json(GameState.from_dict(data).to_dict()), data)


func test_a_lived_in_game_round_trip() -> void:
	var removed_tree := _remove_a_tree()
	_lived_in_state()
	var data := _through_json(_state.to_dict())

	var restored := GameState.from_dict(data)

	assert_eq(_through_json(restored.to_dict()), data)
	assert_eq(restored.player.inventory.count_of(ItemTypes.TURNIP), 3)
	assert_eq(restored.player.inventory.held_item(), ItemTypes.TURNIP_SEEDS)
	assert_eq(restored.clock.day, 2)
	assert_eq(restored.player.position, _state.player.position)
	assert_eq(restored.world.world_seed, SEED)
	assert_eq(restored.world.buildings().size(), 1)
	# The map references point at the restored interior itself.
	var interior := restored.world.buildings()[0].interior
	assert_true(restored.is_inside())
	assert_same(restored.current_map, interior)
	assert_same(restored.player.home_map, interior)
	assert_eq(restored.player.home_bed, _state.player.home_bed)
	assert_eq(interior.object_at(restored.player.home_bed).sleep_minutes() > 0, true)
	# Chunks are regenerated from the seed with the edits replayed.
	_load_chunks_like(_state.world, restored.world)
	assert_null(restored.world.object_at(removed_tree))
	var crop := _crop_in(restored.world)
	assert_not_null(crop)
	assert_eq(crop.days_grown(), 1)
	assert_eq(restored.world.tile_at(crop.pos).terrain, Tile.Terrain.SOIL)
	assert_eq(restored.world.tile_at(_tilled_tile).terrain, Tile.Terrain.SOIL)


func test_loading_does_not_make_a_second_camp() -> void:
	var restored := GameState.from_dict(_through_json(_state.to_dict()))
	_load_chunks_like(_state.world, restored.world)
	var fireplaces := 0
	for coords in restored.world.loaded_chunk_coords():
		for object in restored.world.chunk_at(coords).objects():
			if object.type == WorldObjectTypes.FIREPLACE:
				fireplaces += 1
	assert_eq(fireplaces, 1)
	assert_eq(restored.player.home_bed, _state.player.home_bed)


func test_the_restored_game_carries_on() -> void:
	_lived_in_state()
	var restored := GameState.from_dict(_through_json(_state.to_dict()))
	assert_true(restored.door_underfoot() == _state.door_underfoot())
	restored.player.position = Vector2(restored.current_map.exit_tile) + Vector2(0.5, 0.5)
	restored.pass_door()
	assert_false(restored.is_inside())
	# The new day still grows the crops of the restored world.
	restored.clock.advance(GameClock.MINUTES_PER_DAY)
	_load_chunks_like(_state.world, restored.world)
	assert_eq(_crop_in(restored.world).days_grown(), 2)


func test_enums_are_saved_by_name() -> void:
	var tile := _free_tiles_near_player(1)[0]
	_state.world.set_terrain(tile, Tile.Terrain.SOIL)
	var data := _state.world.to_dict()
	assert_true(data["terrain_edits"].any(func(edit: Array) -> bool: return edit[2] == "SOIL"))
	assert_eq(SaveCodec.terrain_to_json(Tile.Terrain.WALL), "WALL")
	assert_eq(SaveCodec.terrain_from_json("WALL"), Tile.Terrain.WALL)


func test_file_round_trip() -> void:
	_lived_in_state()
	assert_true(SaveFile.write(_state, SAVE_PATH))
	var restored := SaveFile.read(SAVE_PATH)
	assert_eq(_through_json(restored.to_dict()), _through_json(_state.to_dict()))


func test_without_a_file_there_is_no_game_to_load() -> void:
	assert_null(SaveFile.read(SAVE_PATH))


func test_a_version_1_save_loads_with_its_harvest_count_as_turnips() -> void:
	_lived_in_state()
	var game := _through_json(_state.to_dict())
	game["player"].erase("inventory")
	game["harvest_count"] = 4
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "game": game}))
	file.close()

	var restored := SaveFile.read(SAVE_PATH)

	var inventory := restored.player.inventory
	assert_eq(inventory.count_of(ItemTypes.TURNIP), 4)
	assert_eq(inventory.count_of(ItemTypes.HOE), 1)
	assert_eq(inventory.count_of(ItemTypes.TURNIP_SEEDS), 15)
	assert_eq(restored.clock.day, 2)


func test_a_newer_version_is_refused_and_kept_as_backup() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveFile.VERSION + 1, "game": {}}))
	file.close()
	assert_null(SaveFile.read(SAVE_PATH))
	assert_push_error_count(1)
	assert_false(FileAccess.file_exists(SAVE_PATH))
	assert_true(FileAccess.file_exists(SAVE_PATH + SaveFile.BACKUP_SUFFIX))


func test_a_broken_file_is_refused_and_kept_as_backup() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_null(SaveFile.read(SAVE_PATH))
	assert_push_error_count(1)
	assert_true(FileAccess.file_exists(SAVE_PATH + SaveFile.BACKUP_SUFFIX))
