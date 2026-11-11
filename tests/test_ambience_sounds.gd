extends GutTest
## The ambience node: the weather loops start and stop with the weather, thunder follows a flash
## after a delay, a bee that appears buzzes, frogs about croak in chorus on a summer evening, and
## a farm animal calls only while it is awake. The
## audio service is real; what it plays is recorded.

var _state: GameState
var _audio: AudioService
var _ambience: AmbienceSounds
var _wildlife: WildlifeView
var _weather_view: WeatherView
var _events: Array[StringName] = []


func before_each() -> void:
	_state = GameState.new_game(7)
	_audio = AudioService.new()
	add_child_autofree(_audio)
	_audio.played.connect(
		func(event: StringName, _position: Variant) -> void: _events.append(event)
	)
	_wildlife = WildlifeView.new()
	autofree(_wildlife)
	_wildlife.rules = WildlifeRules.default_rules()
	_wildlife.rules.sun = _state.sun
	_wildlife.world_view = WorldView.new()
	add_child_autofree(_wildlife.world_view)
	# As show_wildlife does: the ground is a Node2D nobody frees unless the world view owns it.
	_wildlife.world_view.add_child(_wildlife.ground)
	_weather_view = WeatherView.new()
	add_child_autofree(_weather_view)
	_ambience = AmbienceSounds.new()
	add_child_autofree(_ambience)
	_ambience.listen(_audio, _state, _wildlife, _weather_view)
	# The same dice every run: the chance sounds (a bird, a gust, a frog at water near the
	# player) come the same way each time.
	_ambience._rng.seed = 7
	_events.clear()


func test_rain_and_wind_loops_start_with_a_storm_and_stop_when_it_clears() -> void:
	_state.weather_override = &"storm"
	_ambience._process(1.0)
	assert_true(_events.has(&"rain_loop"))
	assert_true(_events.has(&"wind_loop"))
	_events.clear()
	_state.weather_override = &"clear"
	_ambience._process(1.0)
	assert_eq(_loops(_events), [], "no new loop starts")
	assert_null(_ambience._rain_loop)


## The loops among `events`: a chance sound (a bird, a gust, a frog) may come at any second.
func _loops(events: Array[StringName]) -> Array:
	return events.filter(func(event: StringName) -> bool: return event.ends_with("_loop"))


func test_a_clear_calm_day_has_no_loops() -> void:
	_state.weather_override = &"clear"
	_ambience._process(1.0)
	assert_false(_events.has(&"rain_loop"))


## The ambience rules of the data file with the thunder coming within 0.1 to 0.2 s.
func _quick_thunder_rules() -> AmbienceRules:
	var values := DataFile.read_sections(AmbienceRules.DEFAULT_PATH)
	values["thunder"] = {"min_delay_seconds": 0.1, "max_delay_seconds": 0.2}
	return AmbienceRules.new(values)


func test_thunder_follows_a_flash_after_a_delay() -> void:
	_ambience.rules = _quick_thunder_rules()
	_weather_view.flash()
	assert_false(_events.has(&"thunder"), "not at once")
	await wait_seconds(0.3)
	assert_true(_events.has(&"thunder"))


## Puts a house of Kate's on free ground near the player and takes the player through its door;
## returns the house.
func _enter_kate() -> Building:
	var kate: Building = null
	for offset in 40:
		var origin := _state.player.tile() + Vector2i(offset, 0)
		if _state.world.placement_blockers(BuildingTypes.KATE, origin).is_empty():
			kate = _state.world.place_building(BuildingTypes.KATE, origin)
			break
	assert_not_null(kate, "a place for the house")
	_state.player.position = TerrainTileset.tile_centre(kate.door_tile()) / TerrainTileset.TILE_SIZE
	_state.pass_door()
	return kate


func _fire_in(kate: Building) -> WorldObject:
	for object in kate.inside().objects():
		if object.type == WorldObjectTypes.HEARTH:
			return object
	return null


func test_a_hearth_crackles_in_its_room_from_where_it_burns() -> void:
	var kate := _enter_kate()
	_events.clear()
	_ambience._process(0.1)
	assert_eq(_events.count(&"fire_crackle_loop"), 1, "a gust or a rain loop may come too")
	var hearth := _fire_in(kate)
	var player: AudioStreamPlayer2D = _ambience._fire_loops[hearth]._player
	var middle := (Vector2(hearth.pos) + Vector2(1, 1)) * TerrainTileset.TILE_SIZE
	assert_eq(player.position, middle)
	var reach := AmbienceRules.default_rules().fire_reach(kate.inside().size)
	assert_eq(player.max_distance, reach * TerrainTileset.TILE_SIZE, "fainter the further away")
	assert_eq(player.bus, AudioService.EFFECTS, "not the muffled, turned down buses")


func test_there_is_no_crackle_in_the_open_or_in_a_room_without_a_fire() -> void:
	_ambience._process(1.0)
	assert_false(_events.has(&"fire_crackle_loop"), "outdoors")
	var kate := _enter_kate()
	var room := kate.inside()
	room.remove_object(_fire_in(kate).pos)
	_ambience._process(0.1)
	assert_false(_events.has(&"fire_crackle_loop"), "no fire in the room")


func test_the_crackle_is_not_started_again_while_the_player_stays() -> void:
	_enter_kate()
	_ambience._process(0.1)
	_events.clear()
	_ambience._process(1.0)
	_ambience._process(1.0)
	assert_false(_events.has(&"fire_crackle_loop"))


func test_leaving_the_house_fades_the_crackle_out_and_ends_it() -> void:
	var kate := _enter_kate()
	_ambience._process(0.1)
	var player: AudioStreamPlayer2D = _ambience._fire_loops[_fire_in(kate)]._player
	await wait_seconds(0.8)
	assert_gt(player.volume_db, -20.0, "audible while inside")
	_state.player.position = Vector2(kate.inside().exit_tile) + Vector2(0.5, 0.5)
	_state.pass_door()
	_ambience._process(0.1)
	assert_eq(_ambience._fire_loops.size(), 0)
	var fade_seconds: float = AmbienceRules.default_rules().value("indoors", "fire_fade_seconds")
	await wait_seconds(fade_seconds + 0.3)
	assert_false(is_instance_valid(player), "the loop is gone")


func test_the_crackle_does_not_look_for_fires_while_the_player_is_outdoors() -> void:
	_ambience._process(0.1)
	var stray_fire := WorldObject.new(WorldObjectTypes.HEARTH, Vector2i.ZERO)
	var stray_player := AudioStreamPlayer.new()
	autofree(stray_player)
	_ambience._fire_loops[stray_fire] = SoundLoop.new(stray_player, 0.0, 0.0)
	_ambience._process(0.1)
	assert_true(_ambience._fire_loops.has(stray_fire), "a look would have stopped it")


func test_a_hearth_built_or_taken_out_while_the_player_is_inside_is_followed() -> void:
	var kate := _enter_kate()
	var room := kate.inside()
	var hearth := _fire_in(kate)
	room.remove_object(hearth.pos)
	_ambience._process(1.0)
	assert_eq(_ambience._fire_loops.size(), 0, "taken out")
	room.add_object(hearth)
	_ambience._process(1.0)
	assert_eq(_ambience._fire_loops.size(), 1, "built again")


func test_being_taken_to_the_home_bed_outside_ends_the_crackle() -> void:
	_enter_kate()
	_ambience._process(0.1)
	assert_eq(_ambience._fire_loops.size(), 1)
	_state.player.home_map = _state.world
	_state.player.home_bed = Vector2i.ZERO
	_state.go_to_home_bed()
	_ambience._process(0.1)
	assert_eq(_ambience._fire_loops.size(), 0)


func test_a_game_resumed_inside_a_house_starts_one_crackle() -> void:
	_enter_kate()
	var resumed := AmbienceSounds.new()
	add_child_autofree(resumed)
	resumed.listen(_audio, _state, _wildlife, _weather_view)
	resumed._process(0.1)
	resumed._process(1.0)
	assert_eq(resumed._fire_loops.size(), 1)


func test_a_small_house_hears_its_fire_in_every_corner() -> void:
	var room := InteriorLoader.load_interior("res://maps/interiors/kate.tmx")
	var middle := _fire_middle(room)
	var farthest := 0.0
	for x in room.size.x:
		for y in room.size.y:
			if room.is_walkable(Vector2i(x, y)):
				farthest = maxf(farthest, middle.distance_to(Vector2(x, y) + Vector2(0.5, 0.5)))
	assert_gt(AmbienceRules.default_rules().fire_reach(room.size), farthest)


func test_the_big_longhouse_does_not_hear_its_fire_at_the_door() -> void:
	var room := InteriorLoader.load_interior("res://maps/interiors/longhouse.tmx")
	var at_door := _fire_middle(room).distance_to(Vector2(room.entry_tile()) + Vector2(0.5, 0.5))
	var reach := AmbienceRules.default_rules().fire_reach(room.size)
	assert_lt(reach, at_door)
	assert_gt(reach, 2.0, "but beside the fire")


## The middle of the first fire of a room, in tiles.
func _fire_middle(room: Interior) -> Vector2:
	for object in room.objects():
		if AmbientMotion.has_flames(object.type):
			return Vector2(object.pos) + Vector2(object.type_data()["footprint"]) / 2.0
	return Vector2.INF


func test_a_fireplace_crackles_too_but_an_oven_does_not() -> void:
	var kate := _enter_kate()
	var room := kate.inside()
	room.remove_object(_fire_in(kate).pos)
	room.add_object(WorldObject.new(WorldObjectTypes.OVEN, Vector2i(3, 4)))
	_ambience._process(0.1)
	assert_eq(_ambience._fire_loops.size(), 0, "an oven")
	room.add_object(WorldObject.new(WorldObjectTypes.FIREPLACE, Vector2i(3, 5)))
	_ambience._process(1.0)
	assert_eq(_ambience._fire_loops.size(), 1, "a fireplace")


func test_a_bee_buzzes_where_it_is() -> void:
	_add_bee(Vector2(1, 1))
	_ambience._process(1.0)
	assert_true(_events.has(&"bee_buzz_loop"))


func test_a_buzzing_bee_that_flies_out_of_hearing_goes_quiet() -> void:
	var bee := _add_bee(Vector2(1, 1))
	_ambience._process(1.0)
	assert_eq(_ambience._bee_loops.size(), 1)
	var reach: float = AmbienceRules.default_rules().value("bees", "hear_tiles")
	bee.position += Vector2(reach + 2.0, 0) * TerrainTileset.TILE_SIZE
	_ambience._process(1.0)
	assert_eq(_ambience._bee_loops.size(), 0)


func test_a_bee_out_of_hearing_is_quiet() -> void:
	var reach: float = AmbienceRules.default_rules().value("bees", "hear_tiles")
	_add_bee(Vector2(reach + 1.0, 0))
	_ambience._process(1.0)
	assert_false(_events.has(&"bee_buzz_loop"))


## Adds a bee `offset_tiles` away from the player and returns it.
func _add_bee(offset_tiles: Vector2) -> Bee:
	var bee := Bee.new()
	autofree(bee)
	bee.wildlife = _wildlife
	bee.position = (_state.player.position + offset_tiles) * TerrainTileset.TILE_SIZE
	_ambience._on_animal_added(bee)
	return bee


func test_a_cow_moos_now_and_then_but_not_in_its_sleep() -> void:
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", _state.player.position)
	var cow_view := FarmAnimalView.new(cow)
	add_child_autofree(cow_view)
	cow_view._update(0.0)
	_ambience._on_animal_added(cow_view)
	for _second in 1000:
		_ambience._make_animal_sound()
	assert_true(_events.has(&"cow_moo"))

	_events.clear()
	cow.activity = FarmAnimal.Activity.SLEEP
	cow_view._update(0.0)
	for _second in 1000:
		_ambience._make_animal_sound()
	assert_false(_events.has(&"cow_moo"))


func test_frogs_about_croak_in_chorus_on_a_summer_evening_until_they_are_gone() -> void:
	var values := DataFile.read_sections(AmbienceRules.DEFAULT_PATH)
	# Whatever the weather of the day: warm enough.
	values["frogs"]["cold_temperature"] = -100.0
	values["frogs"]["warm_temperature"] = -90.0
	_ambience.rules = AmbienceRules.new(values)
	_state.clock.day = 45
	_state.clock.minute_of_day = roundi(_state.sun.sunset(45))
	_ambience._process(1.0)
	assert_false(_events.has(&"frog_chorus_loop"), "no frogs, no chorus")
	var frog := Frog.new()
	autofree(frog)
	_ambience._on_animal_added(frog)
	_ambience._process(1.0)
	assert_true(_events.has(&"frog_chorus_loop"))
	_ambience._animals.erase(frog)
	_ambience._process(1.0)
	assert_null(_ambience._chorus_loop, "it stops once the frogs are gone")
