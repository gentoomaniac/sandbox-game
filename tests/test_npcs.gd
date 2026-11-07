extends GutTest
## The villagers: their data file, names and looks, their anchor, and how they go about their day
## (they keep within reach of the anchor on ground they can stand on, stop short of the player,
## turn to the player who speaks to them, and stand still at night).

const SEED := 7
## The yard: a square of grass this many tiles to each side of its middle, ringed by water, with
## a few stones in it. Wider than the anchor's reach, so that only the anchor keeps them in.
const YARD_RADIUS := 9
const STEP_SECONDS := 0.05
const DAY := 45
const NOON := 12 * 60
const MIDNIGHT := 0

var _state: GameState
var _world: World
var _middle: Vector2i
var _npcs: Npcs


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_world = _state.world
	_middle = _state.player.tile() + Vector2i(30, 0)
	var generator := WorldGenerator.new(SEED)
	for y in range(-YARD_RADIUS - 1, YARD_RADIUS + 2):
		for x in range(-YARD_RADIUS - 1, YARD_RADIUS + 2):
			var tile := _middle + Vector2i(x, y)
			var chunk := Chunk.world_to_chunk(tile)
			if not _world.is_chunk_loaded(chunk):
				_world.add_chunk(generator.generate_chunk(chunk))
			_world.remove_object(tile)
			var is_inside := maxi(absi(x), absi(y)) <= YARD_RADIUS
			_world.set_terrain(tile, Tile.Terrain.GRASS if is_inside else Tile.Terrain.WATER)
	for stone in [Vector2i(1, 1), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(4, 3)]:
		_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _middle + stone))
	# Far from the yard, so the villagers have no player to stop short of.
	_state.player.position = Vector2(_middle) + Vector2(0.5, 40.5)
	_npcs = _state.npcs
	_npcs.rng.seed = SEED


func _yard_middle() -> Vector2:
	return Vector2(_middle) + Vector2(0.5, 0.5)


## A villager standing at `feet` and keeping near `anchor`.
func _add_villager(feet: Vector2, anchor: Vector2) -> Npc:
	var npc := Npc.create(SEED, feet, _npcs.rules)
	npc.anchor = anchor
	_npcs.add(npc)
	return npc


func _step(minute := NOON) -> void:
	_state.clock.day = DAY
	_state.clock.minute_of_day = minute
	_npcs.update(STEP_SECONDS, _world, _state.player.position, _state.clock)


func _names_in_file(section: String, key: String) -> Array:
	var file := ConfigFile.new()
	file.load(NpcRules.DEFAULT_PATH)
	return file.get_value(section, key)


# --- The data file ---


func test_the_data_file_holds_every_required_key() -> void:
	var rules := NpcRules.default_rules()
	assert_true(rules.is_valid(), "problems: %s" % [rules.problems()])


func test_every_missing_key_and_empty_list_is_reported() -> void:
	var problems := (
		NpcRules.new({"behaviour": {"walk_speed": 1.0}, "male": {"legs": []}}).problems()
	)
	assert_has(problems, "[behaviour] no anchor_radius")
	assert_does_not_have(problems, "[behaviour] no walk_speed")
	assert_has(problems, "[male] legs is not a list of at least one")
	assert_has(problems, "[everyone] surnames is not a list of at least one")


func test_every_layer_a_villager_may_wear_has_its_sheet() -> void:
	for layer in NpcRules.default_rules().all_layers():
		assert_true(ResourceLoader.exists(Appearance.sheet_path(layer)), str(layer))


# --- Names and looks ---


func test_names_are_a_first_name_of_the_sex_and_a_surname() -> void:
	var surnames := _names_in_file("everyone", "surnames")
	for sex in NpcRules.SEXES:
		var first_names := _names_in_file(str(sex), "first_names")
		for _i in 30:
			var parts := _npcs.rules.pick_name(sex, _npcs.rng).split(" ")
			assert_eq(parts.size(), 2)
			assert_has(first_names, parts[0], "%s is a first name for %s" % [parts[0], sex])
			assert_has(surnames, parts[1])


func test_the_same_seed_gives_the_same_villager() -> void:
	for seed_value in [1, 99, 123456]:
		var first := Npc.create(seed_value, Vector2.ZERO, _npcs.rules)
		var second := Npc.create(seed_value, Vector2.ZERO, _npcs.rules)
		assert_eq(first.name, second.name)
		assert_eq(first.sex, second.sex)
		assert_eq(first.appearance.to_dict(), second.appearance.to_dict())


func test_villagers_come_in_both_sexes_and_women_wear_skirts() -> void:
	var sexes := {}
	for seed_value in 40:
		var npc := Npc.create(seed_value, Vector2.ZERO, _npcs.rules)
		sexes[npc.sex] = true
		var legs: Array = npc.appearance.layers.filter(
			func(layer: Dictionary) -> bool: return layer.slot == Appearance.LEGS
		)
		assert_eq(legs[0].variant.begins_with("skirt"), npc.sex == NpcRules.FEMALE, npc.name)
	assert_eq(sexes.size(), 2)


# --- The anchor ---


func test_a_villager_by_the_camp_is_anchored_to_its_fireplace() -> void:
	var camp := GameState.new_game(SEED)
	var fireplace := CampSite.sleeping_bag_of_seed(SEED) - CampSite.SLEEPING_BAG_OFFSET
	var anchor := Npcs.anchor_near(camp.player.position, camp.world, 16.0)
	assert_eq(anchor, Vector2(fireplace) + Vector2(0.5, 0.5))


func test_the_yard_of_a_nearer_building_wins_over_a_fireplace_further_off() -> void:
	var kate := _world.place_building(BuildingTypes.KATE, _middle + Vector2i(-3, -6))
	assert_not_null(kate)
	var yard := Vector2(kate.door_tile() + Vector2i.DOWN) + Vector2(0.5, 0.5)
	_world.add_object(WorldObject.new(WorldObjectTypes.FIREPLACE, _middle + Vector2i(6, 6)))
	assert_eq(Npcs.anchor_near(yard + Vector2(1, 1), _world, 16.0), yard)


func test_with_nothing_near_the_spot_is_the_anchor() -> void:
	assert_eq(Npcs.anchor_near(_yard_middle(), _world, 5.0), _yard_middle())


func test_spawned_villagers_stand_near_the_point_and_differ() -> void:
	assert_eq(_npcs.spawn(3, _yard_middle(), _world), 3)
	var names := {}
	for npc in _npcs.all():
		assert_lte(npc.position.distance_to(_yard_middle()), Npcs.SPAWN_DISTANCE.y)
		assert_true(PlayerState.can_stand_at(_world, npc.position))
		names[npc.name] = true
	assert_gt(names.size(), 1)


# --- Their day ---


func test_a_villager_never_strays_beyond_its_anchor_and_stands_on_walkable_ground() -> void:
	var npc := _add_villager(_yard_middle(), _yard_middle())
	var radius := _npcs.rules.behaviour("anchor_radius")
	var furthest := 0.0
	for _step_index in int(240.0 / STEP_SECONDS):
		_step()
		furthest = maxf(furthest, npc.position.distance_to(npc.anchor))
		assert_true(PlayerState.can_stand_at(_world, npc.position), str(npc.position))
		if npc.position.distance_to(npc.anchor) > radius:
			fail_test("strayed to %s" % npc.position)
			return
	assert_gt(furthest, 2.0, "it strolled about")


func test_a_villager_outside_its_circle_only_comes_closer() -> void:
	var npc := _add_villager(_yard_middle() + Vector2(8, 0), _yard_middle())
	var distance := npc.position.distance_to(npc.anchor)
	for _step_index in int(60.0 / STEP_SECONDS):
		_step()
		var new_distance := npc.position.distance_to(npc.anchor)
		assert_true(new_distance <= distance + 0.0001 or new_distance <= 6.0)
		distance = new_distance


func test_villagers_stand_still_at_night() -> void:
	var npc := _add_villager(_yard_middle(), _yard_middle())
	npc.activity = Npc.Activity.WALK
	npc.heading = Vector2.RIGHT
	npc.seconds_left = 10.0
	var start := npc.position
	for _step_index in int(30.0 / STEP_SECONDS):
		_step(MIDNIGHT)
	assert_eq(npc.position, start)
	assert_eq(npc.activity, Npc.Activity.IDLE)
	assert_true(_npcs.is_rest_time(DAY, MIDNIGHT))
	assert_false(_npcs.is_rest_time(DAY, NOON))


func test_a_villager_stops_short_of_the_player() -> void:
	var npc := _add_villager(_yard_middle(), _yard_middle())
	_state.player.position = _yard_middle() + Vector2(0.85, 0)
	npc.activity = Npc.Activity.WALK
	npc.heading = Vector2.RIGHT
	npc.seconds_left = 10.0
	_step()
	assert_eq(npc.position, _yard_middle())
	assert_eq(npc.activity, Npc.Activity.IDLE)


func test_spoken_to_a_villager_turns_to_the_player_and_stands_a_while() -> void:
	var npc := _add_villager(_yard_middle(), _yard_middle())
	_state.player.position = _yard_middle() + Vector2(-1.0, 0.2)
	_npcs.talk_to(npc, _state.player.position)
	assert_eq(npc.facing, Vector2i.LEFT)
	for _step_index in int((_npcs.rules.behaviour("linger_seconds") - 0.5) / STEP_SECONDS):
		_step()
	assert_eq(npc.position, _yard_middle())


func test_dropping_old_lines_keeps_the_last_ones_and_holds_the_rest_for_a_memory() -> void:
	var npc := _add_villager(_yard_middle(), _yard_middle())
	for index in 30:
		npc.add_chat_line(DAY, NOON, index % 2 == 0, "line %d" % index)
	npc.drop_old_lines(24)
	assert_eq(npc.chat_history.size(), 24)
	assert_eq(npc.chat_history[0]["text"], "line 6")
	assert_eq(npc.chat_history[-1]["text"], "line 29")
	assert_eq(npc.uncompacted_lines.size(), 6)
	assert_eq(npc.uncompacted_lines[0]["text"], "line 0")


# --- The console ---


func test_spawn_npc_puts_villagers_near_the_player() -> void:
	var console := Console.new(_state)
	_state.player.position = _yard_middle()
	assert_eq(console.run("spawn npc 2"), ["Spawned 2 of 2 npc"] as Array[String])
	assert_eq(_npcs.all().size(), 2)
	assert_eq(console.complete("spawn np"), "spawn npc ")
	assert_eq(_state.livestock.all().size(), 0)
