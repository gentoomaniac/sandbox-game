extends GutTest
## Where the villagers and the farm animals go from the surge (SurgeRefuge, #103).

const SEED := CoastWorld.SEED

var _world: World
var _sun := Sun.new()
var _npcs: Npcs
var _livestock: Livestock
var _activities: ActivityUpkeep
var _refuge: SurgeRefuge


func before_each() -> void:
	_world = CoastWorld.make()
	_npcs = Npcs.new(_sun)
	_livestock = Livestock.new(_sun)
	var homes := Households.new(_npcs)
	_activities = ActivityUpkeep.new(
		_world, _npcs, homes, _sun, StormyWeather.new(SEED), _world.clock
	)
	_refuge = SurgeRefuge.new(_world, _npcs, _livestock, _activities)


func _low_tile() -> Vector2i:
	return CoastWorld.sea_dykes(_world)[10].pos + Vector2i(4, 0)


func _villager_at(tile: Vector2i) -> Npc:
	var npc := Npc.create(3, Vector2(tile) + Vector2(0.5, 0.5), _npcs.rules)
	_npcs.add(npc)
	return npc


func test_a_villager_on_low_land_walks_inland_when_the_surge_is_coming() -> void:
	var npc := _villager_at(_low_tile())
	_world.surge.expect(3.0, _world.clock.total_minutes() + 300, 180)

	_refuge.advance(1, _world.clock)

	assert_true(npc.is_travelling(), "on its way to higher ground")
	assert_gt(npc.trip.goal.x, _low_tile().x + 5)


func test_a_villager_on_the_geest_stays_where_they_are() -> void:
	var npc := _villager_at(_low_tile() + Vector2i(150, 0))
	_world.surge.expect(3.0, _world.clock.total_minutes() + 300, 180)

	_refuge.advance(1, _world.clock)

	assert_false(npc.is_travelling())


func test_the_villagers_day_goes_on_once_the_water_has_drained() -> void:
	var npc := _villager_at(_low_tile())
	_world.surge.expect(3.0, _world.clock.total_minutes() + 300, 180)
	_refuge.advance(1, _world.clock)
	npc.current_step = ActivityStep.new("work", 600)

	_world.surge.clear()
	_refuge.advance(1, _world.clock)

	assert_null(npc.current_step, "sent again by their day")


func test_an_animal_in_the_water_walks_to_the_nearest_dry_ground() -> void:
	_world.surge.expect(3.4, _world.clock.total_minutes(), 180)
	_world.flood.begin(_world, 3.4, _world.clock.total_minutes(), 1)
	_world.flood.settle(_world)
	var tile := _low_tile()
	assert_gt(_world.flood.depth_at(tile), 0.0)
	var sheep := FarmAnimal.new(LivestockRules.SHEEP, &"white", Vector2(tile) + Vector2(0.5, 0.5))
	_livestock.add(sheep)

	_refuge.advance(1, _world.clock)

	assert_true(sheep.goal.is_finite())
	assert_eq(_world.flood.depth_at(Vector2i(sheep.goal.floor())), 0.0, "its goal is dry")


func test_an_animal_with_no_dry_ground_is_not_searched_for_again_at_once() -> void:
	var world := World.new(SEED)
	world.add_chunk(Chunk.new(Vector2i.ZERO))
	var wet := []
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			wet.append([x, y, 80])
	(
		world
		. flood
		. load_dict(
			{
				"flood": {"phase": "standing", "level_cm": 300, "drain_minute": 99999},
				"flood_wet": wet,
				"flood_salt": [],
				"flood_mud": [],
				"flood_repairs": [],
				"flood_met_chunks": [],
			}
		)
	)
	world.surge.expect(3.0, 0, 180)
	var livestock := Livestock.new(_sun)
	var sheep := FarmAnimal.new(LivestockRules.SHEEP, &"white", Vector2(5.5, 5.5))
	livestock.add(sheep)
	var refuge := SurgeRefuge.new(world, _npcs, livestock, _activities)

	refuge.advance(1, world.clock)

	assert_false(sheep.goal.is_finite(), "nowhere to go")
	assert_eq(refuge._next_search_minute[sheep], world.clock.total_minutes() + 60)
