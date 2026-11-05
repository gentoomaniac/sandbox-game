extends ResourceCase
## Seasonal plants in the game state: a fern is dormant in winter (gone, not harvestable, not
## in the way), a berry bush bears only from early summer to late autumn.

const SPRING_START := 1
const SUMMER := 45
const WINTER := 105
const NEXT_SUMMER := SUMMER + GameClock.DAYS_PER_YEAR
## Berries until the last day of the plateau, then none within 4 days, whatever the bush's
## threshold.
const LATE_AUTUMN_CURVES := {
	&"berry_bush": [Vector2(30, 0.0), Vector2(45, 1.0), Vector2(88, 1.0), Vector2(92, 0.0)]
}

# --- Ferns ---


func test_a_fern_is_dormant_in_winter_and_back_in_summer() -> void:
	_state.clock.day = SUMMER
	var fern := _place(WorldObjectTypes.FERN_BUSH)
	assert_same(_world.object_at(_tile), fern)
	_state.clock.day = WINTER
	assert_true(_world.is_dormant(fern))
	assert_null(_world.object_at(_tile))
	_state.clock.day = NEXT_SUMMER
	assert_same(_world.object_at(_tile), fern)


func test_ferns_with_a_low_threshold_are_back_by_late_spring() -> void:
	var early_back := 0
	for x in 100:
		var pos := Vector2i(x, 0)
		var threshold := _world.vegetation.threshold(&"fern_bush", SEED, pos)
		# The fern curve rises to 0.6 by day 25.
		if threshold < 0.5:
			early_back += 1
			assert_true(_world.vegetation.is_present(&"fern_bush", SEED, pos, 25))
		assert_false(_world.vegetation.is_present(&"fern_bush", SEED, pos, SPRING_START))
	assert_gt(early_back, 0)


func test_a_dormant_fern_cant_be_harvested() -> void:
	_state.clock.day = SUMMER
	_place(WorldObjectTypes.FERN_BUSH)
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_at(_tile), GameState.Use.FORAGE)
	_state.clock.day = WINTER
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING)
	assert_eq(_dropped(ItemTypes.FIBRE), 0)


func test_a_dormant_fern_does_not_stand_in_the_way_of_building() -> void:
	_state.clock.day = SUMMER
	_place(WorldObjectTypes.FERN_BUSH)
	assert_false(_world.is_buildable(_tile))
	assert_false(_world.is_free_on(_tile, Tile.Terrain.GRASS))
	_state.clock.day = WINTER
	assert_true(_world.is_buildable(_tile))
	assert_true(_world.is_free_on(_tile, Tile.Terrain.GRASS))
	assert_true(_world.is_walkable(_tile))
	assert_false(_world.placement_blockers(BuildingTypes.SMALL_HOUSE, _tile).has(_tile))


func test_walking_and_building_agree_on_woody_plants_all_year() -> void:
	_place(WorldObjectTypes.BERRY_BUSH)
	for day in [SPRING_START, SUMMER, WINTER]:
		_state.clock.day = day
		assert_not_null(_world.object_at(_tile), "a berry bush never goes dormant")
		assert_false(_world.is_walkable(_tile))
		assert_false(_world.is_buildable(_tile))


func test_a_field_made_where_a_fern_sleeps_has_no_fern_in_spring() -> void:
	_state.clock.day = SUMMER
	_place(WorldObjectTypes.FERN_BUSH)
	_state.clock.day = WINTER
	_hold(ItemTypes.HOE)
	assert_eq(_state.use_facing_tile(), GameState.Use.TILL)
	_state.clock.day = NEXT_SUMMER
	assert_null(_world.object_at(_tile))
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)


func test_an_object_put_on_a_dormant_fern_replaces_it() -> void:
	_state.clock.day = SUMMER
	_place(WorldObjectTypes.FERN_BUSH)
	_state.clock.day = WINTER
	var stone := _place(WorldObjectTypes.STONE)
	assert_same(_world.object_at(_tile), stone)
	_state.clock.day = NEXT_SUMMER
	assert_same(_world.object_at(_tile), stone)


func test_a_harvested_fern_stays_removed() -> void:
	_state.clock.day = SUMMER
	_place(WorldObjectTypes.FERN_BUSH)
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
	assert_eq(_dropped(ItemTypes.FIBRE), 2)
	_state.clock.day = NEXT_SUMMER
	assert_null(_world.object_at(_tile))


func test_a_generated_fern_is_dormant_in_winter_across_chunk_reloads_and_saves() -> void:
	var fern := _find_generated_fern()
	_tile = fern.pos
	_state.clock.day = SUMMER
	assert_same(_world.object_at(fern.pos), fern)
	_state.clock.day = WINTER
	assert_null(_world.object_at(fern.pos))
	_reload_chunk()
	assert_null(_world.object_at(fern.pos), "still dormant after the chunk loads again")
	var restored := _through_save()
	assert_eq(restored.clock.day, WINTER)
	assert_null(restored.world.object_at(fern.pos), "and after a save")
	restored.clock.day = NEXT_SUMMER
	assert_not_null(restored.world.object_at(fern.pos))


func test_a_fern_the_player_changed_is_dormant_after_a_save_too() -> void:
	_state.clock.day = SUMMER
	_place(WorldObjectTypes.FERN_BUSH)
	_state.clock.day = WINTER
	var restored := _through_save()
	assert_null(restored.world.object_at(_tile))
	restored.clock.day = NEXT_SUMMER
	assert_eq(restored.world.object_at(_tile).type, WorldObjectTypes.FERN_BUSH)


# --- Berries ---


func test_berries_can_be_picked_in_summer_but_not_in_winter() -> void:
	var bush := _place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.NONE)
	_state.clock.day = WINTER
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	assert_true(_world.is_bare(bush))
	assert_ne(ObjectTileset.atlas_cell(bush, true), ObjectTileset.atlas_cell(bush), "looks picked")
	_state.clock.day = SUMMER
	assert_false(_world.is_bare(bush))
	assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
	assert_eq(_dropped(ItemTypes.BERRIES), 3)


func test_a_bush_has_no_berries_in_early_spring_either() -> void:
	var bush := _place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.NONE)
	_state.clock.day = SPRING_START
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	assert_true(_world.is_bare(bush))


func test_a_bush_picked_in_late_autumn_has_no_berries_until_the_next_window() -> void:
	_world.vegetation = Vegetation.from_curves(LATE_AUTUMN_CURVES)
	var bush := _place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.NONE)
	_state.clock.day = 88
	assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
	assert_true(bush.is_picked())
	_sleep_days(3)
	assert_false(bush.is_picked(), "it would bear again by now")
	_state.clock.day = 93
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING, "but the season is over")
	_state.clock.day = WINTER
	assert_true(_world.is_bare(bush))
	_state.clock.day = NEXT_SUMMER
	assert_eq(_state.use_at(_tile), GameState.Use.FORAGE)
	assert_eq(ObjectTileset.atlas_cell(bush, _world.is_bare(bush)), ObjectTileset.atlas_cell(bush))


func test_picking_in_season_bears_again_after_three_days_as_before() -> void:
	var bush := _place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.NONE)
	_state.clock.day = SUMMER
	assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	_sleep_days(3)
	assert_false(bush.is_picked())
	assert_eq(_state.use_at(_tile), GameState.Use.FORAGE)


func _find_generated_fern() -> WorldObject:
	var generator := WorldGenerator.new(SEED)
	for y in range(-3, 3):
		for x in range(-3, 3):
			var chunk := generator.generate_chunk(Vector2i(x, y))
			for object in chunk.objects():
				if object.type == WorldObjectTypes.FERN_BUSH:
					_world.add_chunk(chunk)
					return object
	fail_test("no generated fern near the origin")
	return null
