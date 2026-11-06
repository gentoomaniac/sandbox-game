extends GutTest
## Which sound event the ground under the player, a tool hit or a use makes.


func test_footstep_by_ground() -> void:
	var cases := {
		Tile.Terrain.GRASS: &"step_grass",
		Tile.Terrain.SOIL: &"step_soil",
		Tile.Terrain.WETLAND: &"step_wetland",
		Tile.Terrain.FLOODPLAIN: &"step_sand",
		Tile.Terrain.FLOOR: &"step_wood",
	}
	for terrain in cases:
		assert_eq(SoundEvents.footstep(terrain, false, false, false), cases[terrain], str(terrain))


func test_frozen_water_sounds_like_ice() -> void:
	assert_eq(SoundEvents.footstep(Tile.Terrain.WATER, true, false, false), &"step_ice")


func test_snow_lies_over_the_ground() -> void:
	for terrain in [Tile.Terrain.GRASS, Tile.Terrain.SOIL, Tile.Terrain.FLOODPLAIN]:
		assert_eq(SoundEvents.footstep(terrain, false, true, false), &"step_snow", str(terrain))
	assert_eq(SoundEvents.footstep(Tile.Terrain.WATER, true, true, false), &"step_snow")


func test_indoors_clogs_clack_on_brick_and_tread_on_clay() -> void:
	assert_eq(SoundEvents.footstep(Tile.Terrain.FLOOR, false, false, true), &"step_wood")
	assert_eq(SoundEvents.footstep(Tile.Terrain.GRASS, false, true, true), &"step_wood")
	assert_eq(SoundEvents.footstep(Tile.Terrain.CLAY_FLOOR, false, false, true), &"step_soil")


func test_an_axe_chops_and_the_felling_blow_too() -> void:
	var oak: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.OAK]
	var trunk: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.trunk_type(
		WorldObjectTypes.OAK, false
	)]
	var stump: Dictionary = WorldObjectTypes.TYPES[WorldObjectTypes.STUMP]
	assert_eq(SoundEvents.hit(oak, false), &"axe_chop")
	assert_eq(SoundEvents.hit(oak, true), &"axe_chop", "the fall is heard on landing")
	assert_eq(SoundEvents.hit(trunk, false), &"axe_chop")
	assert_eq(SoundEvents.hit(trunk, true), &"axe_chop", "cutting up a trunk is a chop")
	assert_eq(SoundEvents.hit(stump, true), &"axe_chop")


func test_a_pickaxe_hits_and_a_stone_breaks() -> void:
	for type in [WorldObjectTypes.STONE, WorldObjectTypes.BOULDER]:
		var data: Dictionary = WorldObjectTypes.TYPES[type]
		assert_eq(SoundEvents.hit(data, false), &"pickaxe_hit", str(type))
		assert_eq(SoundEvents.hit(data, true), &"stone_break", str(type))


func test_each_use_has_its_sound() -> void:
	var cases := {
		ToolUse.Use.TILL: &"hoe_till",
		ToolUse.Use.PLANT: &"plant",
		ToolUse.Use.HARVEST: &"pick_bush",
		ToolUse.Use.FORAGE: &"pick_bush",
		ToolUse.Use.CLEAR: &"pick_bush",
		ToolUse.Use.WATER: &"water_pour",
		ToolUse.Use.MOW: &"scythe_swish",
		ToolUse.Use.DIG: &"shovel_dig",
		ToolUse.Use.NEEDS_BETTER_TOOL: &"denied",
		ToolUse.Use.HIT: &"",
	}
	for use in cases:
		assert_eq(SoundEvents.use(use, ItemTypes.HOE), cases[use], str(use))


func test_a_scythe_swishes_even_when_it_mows_nothing() -> void:
	assert_eq(SoundEvents.use(ToolUse.Use.NOTHING, ItemTypes.SCYTHE), &"scythe_swish")
	assert_eq(SoundEvents.use(ToolUse.Use.NOTHING, ItemTypes.AXE), &"")


func test_every_event_made_is_a_known_event() -> void:
	var made: Array[StringName] = []
	for use in ToolUse.Use.values():
		made.append(SoundEvents.use(use, ItemTypes.SCYTHE))
	for type: Dictionary in WorldObjectTypes.TYPES.values():
		made.append(SoundEvents.hit(type, true))
		made.append(SoundEvents.hit(type, false))
	for event in made:
		assert_true(event == &"" or SoundRules.EVENTS.has(event), str(event))


func test_animal_sounds_are_events_of_the_sound_data() -> void:
	for kind in WildlifeRules.KINDS + LivestockRules.SPECIES:
		for event in [
			SoundEvents.animal_idle(kind),
			SoundEvents.animal_alarm(kind, Deer.BOUND),
			SoundEvents.animal_alarm(kind, Rabbit.FLEE),
		]:
			assert_true(event == &"" or SoundRules.EVENTS.has(event), str(event))


func test_deer_rabbits_and_squirrels_make_sounds_of_their_own() -> void:
	assert_eq(SoundEvents.animal_idle(WildlifeRules.DEER), &"deer_snort")
	assert_eq(SoundEvents.animal_idle(WildlifeRules.RABBIT), &"rabbit_rustle")
	assert_eq(SoundEvents.animal_idle(WildlifeRules.SQUIRREL), &"squirrel_chatter")
	assert_eq(SoundEvents.animal_idle(WildlifeRules.BIRD), &"", "birds chirp by the ambience")


func test_the_farm_animals_moo_baa_and_cluck() -> void:
	assert_eq(SoundEvents.animal_idle(LivestockRules.COW), &"cow_moo")
	assert_eq(SoundEvents.animal_idle(LivestockRules.SHEEP), &"sheep_baa")
	assert_eq(SoundEvents.animal_idle(LivestockRules.CHICKEN), &"chicken_cluck")
	assert_eq(
		SoundEvents.animal_idle(LivestockRules.RABBIT), &"rabbit_rustle", "a rabbit is a rabbit"
	)


func test_animals_that_run_make_a_sound_when_they_start() -> void:
	assert_eq(SoundEvents.animal_alarm(WildlifeRules.DEER, Deer.BOUND), &"deer_hooves")
	assert_eq(SoundEvents.animal_alarm(WildlifeRules.RABBIT, Rabbit.FLEE), &"rabbit_rustle")
	assert_eq(SoundEvents.animal_alarm(WildlifeRules.SQUIRREL, Squirrel.FLEE), &"squirrel_chatter")
	assert_eq(SoundEvents.animal_alarm(WildlifeRules.DEER, Deer.GRAZE), &"")
	assert_eq(SoundEvents.animal_alarm(WildlifeRules.RABBIT, Rabbit.HOP), &"")
