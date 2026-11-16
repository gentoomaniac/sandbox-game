extends GutTest
## The track from the camp to the village's main lane, laid at the start as desire path wear, which
## fades with the days like any other when nobody walks it (design/world/wehlsbuell.md, section 7).

const SEEDS := [1, 4, 7]

var _plan := VillagePlan.default_plan()


func _track_of(state: GameState) -> Array[Vector2i]:
	var worn: Array[Vector2i] = []
	worn.assign(state.world.wear_days().keys())
	return worn


func test_the_way_joins_the_camp_and_the_end_of_the_main_lane() -> void:
	for world_seed: int in SEEDS:
		var site := VillageSite.find(world_seed)
		var way := site.camp_way
		var camp := CampSite.spawn_of_seed(world_seed)
		assert_gt(way.size(), 100, "seed %d" % world_seed)
		assert_lte((way[0] - camp).abs().x + (way[0] - camp).abs().y, 2, "seed %d" % world_seed)
		assert_eq(way[-1], site.to_world(_plan.main_lane_end()), "seed %d" % world_seed)
		for index in range(1, way.size()):
			assert_eq((way[index] - way[index - 1]).length_squared(), 1, "%s" % way[index])


func test_a_new_game_has_the_wear_of_a_path_on_the_wearable_tiles_of_the_way_and_nowhere_else(
) -> void:
	var most_days := PathRules.default_rules().most_days()
	for world_seed: int in SEEDS:
		var state := GameFactory.new_game(world_seed, true)
		var way := VillageSite.find(world_seed).camp_way
		var worn := _track_of(state)
		assert_gt(worn.size(), way.size() / 2, "seed %d: most of the way wears" % world_seed)
		for tile in worn:
			assert_true(way.has(tile), "%s of seed %d is not on the way" % [tile, world_seed])
			assert_eq(state.world.wear_days()[tile], most_days)
			assert_eq(state.world.wear_stage(tile), PathRules.Stage.PATH)


func test_the_track_fades_to_grass_when_nobody_walks_it() -> void:
	var state := GameFactory.new_game(1, true)
	var track := _track_of(state)
	assert_gt(track.size(), 100)

	state.world.end_wear_day()
	for tile in track:
		assert_eq(state.world.wear_stage(tile), PathRules.Stage.PATH, "after a day")

	for _day in 10:
		state.world.end_wear_day()
	for tile in track:
		assert_eq(state.world.wear_stage(tile), PathRules.Stage.UNWORN, "after eleven days")

	state.world.end_wear_day()
	assert_true(_track_of(state).is_empty(), "no wear left after twelve")


func test_a_game_without_the_village_has_no_track() -> void:
	assert_true(_track_of(GameFactory.new_game(7)).is_empty())
