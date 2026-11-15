extends NpcRoadCase
## What a time skip lets a villager walk through (#68): each tile is asked at the minute the walker
## enters it, in the world as it is at the skip's end: the tide and the season of the time of
## entry, not those of the clock, and an edit of the night as it stands then.

const MUD_X := 60

var _original_types := WorldObjectTypes.TYPES


func before_each() -> void:
	super()
	_build_road()


func after_each() -> void:
	WorldObjectTypes.TYPES = _original_types


## Makes `tile` mud, which is edited on its chunk and stays when the chunk is unloaded again.
func _make_mud(tile: Vector2i) -> void:
	var coords := Chunk.world_to_chunk(tile)
	var was_loaded := _world.is_chunk_loaded(coords)
	_load(coords)
	_world.set_terrain(tile, Tile.Terrain.MUD)
	if not was_loaded:
		_world.remove_chunk(coords)


## A minute of the day to start a skip of `skip_minutes` at, such that the tide covers `tile` at
## `entry_after` minutes later exactly when `is_flooded_at_entry`, and the opposite at the end.
func _start_with_tide(
	tile: Vector2i, entry_after: int, skip_minutes: int, is_flooded_at_entry: bool
) -> int:
	var day_start := (DAY - 1) * GameClock.MINUTES_PER_DAY
	for start in range(0, GameClock.MINUTES_PER_DAY - skip_minutes):
		var at_entry := Tide.floods(tile, Tide.level(day_start + start + entry_after))
		var at_end := Tide.floods(tile, Tide.level(day_start + start + skip_minutes))
		if at_entry == is_flooded_at_entry and at_end != is_flooded_at_entry:
			return start
	return -1


## Lets a skip of `minutes` that started at the minute `start` of the day end.
func _skip_from(start: int, minutes: int) -> void:
	_state.clock.minute_of_day = start + minutes
	_npcs.catch_up(_world, 1, minutes)


## A walker from the road's tile `from_x` meets the mud tile at `mud_x` in a skip of `minutes`.
func _check_tide_at_entry(mud_x: int, from_x: int, minutes: int) -> void:
	var mud := _road_tile(mud_x)
	var entry_after := from_x - mud_x - 1
	_make_mud(mud)
	_warm_road_masks()
	var start := _start_with_tide(mud, entry_after, minutes, false)
	assert_gte(start, 0, "the tide is out when it enters and in at the end")
	var npc := _walker_on_road(from_x, 0)
	_skip_from(start, minutes)
	assert_eq(npc.tile(), _road_tile(from_x - minutes), "the tide at the end did not stop it")

	start = _start_with_tide(mud, entry_after, minutes, true)
	assert_gte(start, 0, "the tide is in when it enters and out at the end")
	_send_along_road(npc, from_x, 0)
	_skip_from(start, minutes)
	assert_eq(npc.tile(), mud + Vector2i.RIGHT, "the tide at its entry stopped it before the mud")
	assert_eq(npc.trip.state, NpcTrip.State.WALKING, "it searches after the skip")


func test_the_tide_at_the_time_of_entry_stops_a_walker_on_a_far_path() -> void:
	assert_false(_is_loaded(_road_tile(MUD_X)))
	_check_tide_at_entry(MUD_X, ROAD_LENGTH, 60)


func test_the_tide_at_the_time_of_entry_stops_a_walker_inside_the_loaded_area() -> void:
	var mud_x := YARD_RADIUS + 3
	assert_true(_is_loaded(_road_tile(mud_x)))
	_check_tide_at_entry(mud_x, mud_x + 6, 8)


## A day on which the fern at `tile` is there and the next it is not, or the other way round.
func _day_of_change(tile: Vector2i, is_present_first: bool) -> int:
	for day in range(1, GameClock.DAYS_PER_YEAR):
		var first := _world.vegetation.is_present(WorldObjectTypes.FERN_BUSH, SEED, tile, day)
		var second := _world.vegetation.is_present(WorldObjectTypes.FERN_BUSH, SEED, tile, day + 1)
		if first == is_present_first and second != is_present_first:
			return day
	return -1


## A skip over midnight: 60 minutes from 23:30 of `day`, over a fern that blocks while it is there,
## at the road's tile 95 (the walker enters it at 23:34).
func _skip_over_a_fern(day: int) -> Npc:
	var types := _original_types.duplicate(true)
	types[WorldObjectTypes.FERN_BUSH]["blocks_walking"] = true
	WorldObjectTypes.TYPES = types
	var tile := _road_tile(95)
	var coords := Chunk.world_to_chunk(tile)
	_load(coords)
	_world.add_object(WorldObject.new(WorldObjectTypes.FERN_BUSH, tile))
	_world.remove_chunk(coords)
	_warm_road_masks()
	var npc := _walker_on_road(ROAD_LENGTH, 0)
	_state.clock.day = day + 1
	_state.clock.minute_of_day = 30
	_npcs.catch_up(_world, 1, 60)
	return npc


func test_a_seasonal_plant_there_at_the_time_of_entry_stops_one_though_gone_at_the_end() -> void:
	var day := _day_of_change(_road_tile(95), true)
	assert_gt(day, 0, "the fern is there one day and not the next")
	var npc := _skip_over_a_fern(day)
	assert_eq(npc.tile(), _road_tile(96))


func test_a_seasonal_plant_there_only_at_the_end_does_not_stop_one() -> void:
	var day := _day_of_change(_road_tile(95), false)
	assert_gt(day, 0, "the fern is not there one day and is the next")
	var npc := _skip_over_a_fern(day)
	assert_eq(npc.tile(), _road_tile(ROAD_LENGTH - 60))


func test_a_sapling_that_grew_into_a_tree_in_the_skip_stops_the_walker_there() -> void:
	var tile := _road_tile(70)
	var coords := Chunk.world_to_chunk(tile)
	_load(coords)
	var sapling := WorldObject.new(WorldObjectTypes.SAPLING, tile)
	sapling.state["tree"] = WorldObjectTypes.SPRUCE
	_world.add_object(sapling)
	_warm_road_masks()
	var npc := _walker_on_road(ROAD_LENGTH, 0)
	_world.replace_object(sapling, sapling.matured())
	_world.remove_chunk(coords)
	_warm_road_masks()
	_skip_from(3 * 60, 60)
	assert_eq(npc.tile(), tile + Vector2i.RIGHT, "the tree of the end of the skip stops it")
