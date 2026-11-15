extends ResourceCase
## Footprints in snow and mud (#64): a step onto soft ground leaves a print and one onto grass,
## a way or flooded mud does not; the prints fade by the weather, a chunk keeps a few and drops
## them when it is unloaded.

const MUD_TILE := Vector2i(8, 8)

var _footprints: Footprints
var _is_snowed := false


func before_each() -> void:
	super.before_each()
	_footprints = _world.footprints
	_is_snowed = false
	_footprints.is_snowed_at = func(_tile: Vector2i) -> bool: return _is_snowed
	_world.set_terrain(_tile, Tile.Terrain.GRASS)


func _ring_size(tile: Vector2i) -> int:
	var ring := _footprints.ring_of(Chunk.world_to_chunk(tile))
	return 0 if ring == null else ring.size


func _wear_to_path(tile: Vector2i) -> void:
	_world.set_wear_days(tile, PathRules.default_rules().path_after_days())


## Sets tidal mud and moves the clock to a minute at which the tide has left it dry (or covers it).
func _make_mud_with_tide(tile: Vector2i, is_flooded: bool) -> void:
	_world.set_terrain(tile, Tile.Terrain.MUD)
	for minute in range(0, 24 * 60, 10):
		_world.clock.minute_of_day = minute
		if _world.is_flooded(tile) == is_flooded:
			return
	fail_test("the tide never gave %s" % is_flooded)


func test_a_step_in_snow_leaves_a_print() -> void:
	_is_snowed = true
	_footprints.step(_world, _tile, Vector2.RIGHT)
	assert_eq(_ring_size(_tile), 1)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	assert_eq(_footprints.kind_of_slot(ring, 0), Footprints.Kind.SNOW)


func test_grass_takes_no_print() -> void:
	_footprints.step(_world, _tile, Vector2.RIGHT)
	assert_eq(_ring_size(_tile), 0)


func test_worn_ground_takes_prints_only_while_the_rain_makes_it_mud() -> void:
	_wear_to_path(_tile)
	_footprints.step(_world, _tile, Vector2.RIGHT)
	assert_eq(_ring_size(_tile), 0, "dry")
	_world.set_muddy(true)
	_footprints.step(_world, _tile, Vector2.RIGHT)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	assert_eq(_footprints.kind_of_slot(ring, 0), Footprints.Kind.MUD)


func test_tidal_mud_takes_prints_when_dry_and_none_when_the_tide_covers_it() -> void:
	_make_mud_with_tide(MUD_TILE, true)
	_footprints.step(_world, MUD_TILE, Vector2.RIGHT)
	assert_eq(_ring_size(MUD_TILE), 0, "flooded")
	_make_mud_with_tide(MUD_TILE, false)
	_footprints.step(_world, MUD_TILE, Vector2.RIGHT)
	assert_eq(_ring_size(MUD_TILE), 1, "dry")


func test_a_way_takes_no_print_in_snow() -> void:
	_is_snowed = true
	_place(WorldObjectTypes.PLANK_WALK)
	_footprints.step(_world, _tile, Vector2.RIGHT)
	assert_eq(_ring_size(_tile), 0)


func test_the_feet_alternate_and_the_toes_point_the_way_the_walker_goes() -> void:
	_is_snowed = true
	var ring_cells := []
	for x in 4:
		_footprints.step(_world, _tile + Vector2i(x, 0), Vector2.RIGHT)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	for slot in 4:
		ring_cells.append(ring.cell[slot])
		assert_eq(ring.quarter_turns[slot], 1, "toes to the east")
	assert_ne(ring_cells[0], ring_cells[1])
	assert_eq(ring_cells[0], ring_cells[2])
	_footprints.step(_world, _tile + Vector2i(0, 2), Vector2.UP)
	assert_eq(ring.quarter_turns[4], 0)
	_footprints.step(_world, _tile + Vector2i(0, 3), Vector2.LEFT)
	assert_eq(ring.quarter_turns[5], 3)
	_footprints.step(_world, _tile + Vector2i(0, 4), Vector2.DOWN)
	assert_eq(ring.quarter_turns[6], 2)


func test_a_print_lies_within_its_tile() -> void:
	_is_snowed = true
	for heading in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_footprints.step(_world, _tile, heading)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	for slot in ring.size:
		assert_eq(Vector2i(ring.position[slot].floor()), _tile)


func test_a_print_fades_over_its_time_and_faster_in_rain() -> void:
	var rules := FootprintRules.default_rules()
	_footprints.advance_to(0, 0.0, 0.0, 0.0)
	assert_eq(
		_footprints.opacity_of(Footprints.Kind.MUD, _footprints.age_of(Footprints.Kind.MUD)), 1.0
	)
	_footprints.advance_to(int(rules.mud_lasts_minutes() / 2.0), 0.0, 0.0, 0.0)
	assert_almost_eq(_footprints.opacity_of(Footprints.Kind.MUD, 0.0), 0.5, 0.01, "half the time")
	var rainy := Footprints.new()
	rainy.advance_to(0, 1.0, 0.0, 0.0)
	rainy.advance_to(int(rules.mud_lasts_minutes() / (1.0 + rules.mud_rain_gain())), 1.0, 0.0, 0.0)
	assert_eq(rainy.opacity_of(Footprints.Kind.MUD, 0.0), 0.0, "gone after a shorter time in rain")


func test_snow_prints_fade_faster_in_snowfall_and_thaw_and_mud_ones_do_not() -> void:
	var minutes := 100
	var fair := Footprints.new()
	var snowing := Footprints.new()
	var thawing := Footprints.new()
	for footprints in [fair, snowing, thawing]:
		footprints.advance_to(0, 0.0, 0.0, 0.0)
	fair.advance_to(minutes, 0.0, 0.0, 0.0)
	snowing.advance_to(minutes, 0.0, 1.0, 0.0)
	thawing.advance_to(minutes, 0.0, 0.0, 1.0)
	assert_lt(
		snowing.opacity_of(Footprints.Kind.SNOW, 0.0), fair.opacity_of(Footprints.Kind.SNOW, 0.0)
	)
	assert_lt(
		thawing.opacity_of(Footprints.Kind.SNOW, 0.0), fair.opacity_of(Footprints.Kind.SNOW, 0.0)
	)
	assert_eq(
		snowing.opacity_of(Footprints.Kind.MUD, 0.0), fair.opacity_of(Footprints.Kind.MUD, 0.0)
	)


func test_a_chunk_keeps_its_last_prints_and_overwrites_the_oldest() -> void:
	_is_snowed = true
	var cap := FootprintRules.default_rules().per_chunk()
	for index in cap + 3:
		_footprints.step(_world, _tile + Vector2i(index % 2, 0), Vector2.RIGHT)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	assert_eq(ring.size, cap)
	assert_eq(ring.next, 3, "the next print overwrites the fourth oldest")
	assert_eq(ring.born.size(), cap, "no growth")


func test_a_print_on_a_chunk_that_is_not_loaded_is_not_made() -> void:
	_is_snowed = true
	_footprints.step(_world, Vector2i(5000, 5000), Vector2.RIGHT)
	assert_null(_footprints.ring_of(Chunk.world_to_chunk(Vector2i(5000, 5000))))


func test_unloading_a_chunk_drops_its_prints() -> void:
	_is_snowed = true
	_footprints.step(_world, _tile, Vector2.RIGHT)
	var coords := Chunk.world_to_chunk(_tile)
	_footprints.forget_chunk(coords)
	assert_null(_footprints.ring_of(coords))


func test_a_print_is_gone_when_its_ground_is_not_soft_any_more() -> void:
	_is_snowed = true
	_footprints.step(_world, _tile, Vector2.RIGHT)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	_footprints.check_next_chunk(_world)
	assert_ne(ring.born[0], Footprints.GONE, "the snow lies on")
	_is_snowed = false
	_footprints.check_next_chunk(_world)
	assert_eq(ring.born[0], Footprints.GONE, "the snow melted")


func test_a_print_in_mud_is_gone_when_the_tide_covers_it() -> void:
	_make_mud_with_tide(MUD_TILE, false)
	_footprints.step(_world, MUD_TILE, Vector2.RIGHT)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(MUD_TILE))
	_make_mud_with_tide(MUD_TILE, true)
	_footprints.check_next_chunk(_world)
	assert_eq(ring.born[0], Footprints.GONE)


func test_checking_a_chunk_makes_no_new_print_and_visits_each_in_turn() -> void:
	_is_snowed = true
	_footprints.step(_world, _tile, Vector2.RIGHT)
	var size_before := _ring_size(_tile)
	for _i in 5:
		_footprints.check_next_chunk(_world)
	assert_eq(_ring_size(_tile), size_before)


func test_the_player_leaves_prints_on_foot_and_not_on_horseback() -> void:
	_is_snowed = true
	_state.player.position = Vector2(_tile) + Vector2(0.9, 0.5)
	_state.walk(Vector2.RIGHT, 0.2)
	assert_eq(_ring_size(_tile + Vector2i.RIGHT), 1)
	_state.player.horse = FarmAnimal.new(LivestockRules.HORSE, &"bay", _state.player.position)
	_state.walk(Vector2.RIGHT, 0.5)
	assert_eq(_ring_size(_tile + Vector2i.RIGHT), 1, "the horse's hooves are for #65")


func test_a_villager_leaves_a_print_for_a_step_onto_a_new_tile_only() -> void:
	_is_snowed = true
	var from_tile := _tile
	Npcs.leave_footprint(_world, Vector2(from_tile) + Vector2(0.8, 0.5), from_tile)
	assert_eq(_ring_size(_tile), 0, "same tile")
	Npcs.leave_footprint(_world, Vector2(from_tile) + Vector2(1.1, 0.5), from_tile)
	assert_eq(_ring_size(_tile), 1)
	var ring := _footprints.ring_of(Chunk.world_to_chunk(_tile))
	assert_eq(ring.quarter_turns[0], 1, "east")


func test_the_data_file_is_valid() -> void:
	assert_eq(FootprintRules.default_rules().problems(), [])
