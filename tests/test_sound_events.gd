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


func test_indoors_it_is_the_wooden_floor() -> void:
	assert_eq(SoundEvents.footstep(Tile.Terrain.FLOOR, false, false, true), &"step_wood")
	assert_eq(SoundEvents.footstep(Tile.Terrain.GRASS, false, true, true), &"step_wood")


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
		GameState.Use.TILL: &"hoe_till",
		GameState.Use.PLANT: &"plant",
		GameState.Use.HARVEST: &"pick_bush",
		GameState.Use.FORAGE: &"pick_bush",
		GameState.Use.CLEAR: &"pick_bush",
		GameState.Use.WATER: &"water_pour",
		GameState.Use.MOW: &"scythe_swish",
		GameState.Use.DIG: &"shovel_dig",
		GameState.Use.NEEDS_BETTER_TOOL: &"denied",
		GameState.Use.HIT: &"",
	}
	for use in cases:
		assert_eq(SoundEvents.use(use, ItemTypes.HOE), cases[use], str(use))


func test_a_scythe_swishes_even_when_it_mows_nothing() -> void:
	assert_eq(SoundEvents.use(GameState.Use.NOTHING, ItemTypes.SCYTHE), &"scythe_swish")
	assert_eq(SoundEvents.use(GameState.Use.NOTHING, ItemTypes.AXE), &"")


func test_every_event_made_is_a_known_event() -> void:
	var made: Array[StringName] = []
	for use in GameState.Use.values():
		made.append(SoundEvents.use(use, ItemTypes.SCYTHE))
	for type: Dictionary in WorldObjectTypes.TYPES.values():
		made.append(SoundEvents.hit(type, true))
		made.append(SoundEvents.hit(type, false))
	for event in made:
		assert_true(event == &"" or SoundRules.EVENTS.has(event), str(event))
