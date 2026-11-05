extends ResourceCase
## The seeds of the trees: felled living trees drop them by chance, they plant on grass and grow
## into a tree of their species.

const SEEDS := {
	WorldObjectTypes.OAK: ItemTypes.ACORN,
	WorldObjectTypes.SPRUCE: ItemTypes.SPRUCE_CONE,
	WorldObjectTypes.PINE: ItemTypes.PINE_CONE,
}
const STRONG_AXE := &"strong_axe"


func before_each() -> void:
	super.before_each()
	_make_room()
	# The pine needs a level 2 axe, which the game doesn't have yet.
	ItemTypes.TYPES[STRONG_AXE] = {
		"name": "Strong axe", "weight": 3.0, "stack_limit": 1, "tool": ItemTypes.AXE, "level": 2
	}


func after_each() -> void:
	ItemTypes.TYPES.erase(STRONG_AXE)


## The seeds dropped by felling a tree of this type on each of the days 1 to `days`, in that
## order (one entry per day). The strong axe has power 2.
func _seeds_dropped_over(tree: StringName, seed_item: StringName, days: int) -> Array[int]:
	var seeds: Array[int] = []
	for day in range(1, days + 1):
		_state.clock.day = day
		for x in range(-2, 3):
			_world.remove_object(_tile + Vector2i(x, 0))
		_clear_ground()
		_place(tree)
		_hit(STRONG_AXE, ceili(WorldObjectTypes.TYPES[tree]["hp"] / 2.0))
		seeds.append(_dropped(seed_item))
	return seeds


func _total(counts: Array[int]) -> int:
	return counts.reduce(func(sum: int, count: int) -> int: return sum + count, 0)


# --- Dropping ---


func test_each_living_tree_drops_its_own_seed_with_about_a_quarter_chance() -> void:
	for tree: StringName in SEEDS:
		var first := _seeds_dropped_over(tree, SEEDS[tree], 100)
		assert_eq(_seeds_dropped_over(tree, SEEDS[tree], 100), first, "%s is deterministic" % tree)
		assert_between(_total(first), 12, 40, tree)


func test_a_dead_tree_gives_no_seed() -> void:
	for day in range(1, 60):
		_state.clock.day = day
		_world.remove_object(_tile)
		_world.remove_object(_tile + Vector2i.RIGHT)
		_world.remove_object(_tile + Vector2i.RIGHT * 2)
		_place(WorldObjectTypes.DEAD_TREE)
		_hit(ItemTypes.AXE, 3)
	for seed_item: StringName in SEEDS.values():
		assert_eq(_dropped(seed_item), 0)


func test_the_generic_sapling_item_is_gone() -> void:
	assert_false(ItemTypes.TYPES.has(&"sapling"))


# --- Planting ---


func test_a_seed_plants_a_sapling_of_its_species_that_grows_into_the_tree() -> void:
	for tree: StringName in SEEDS:
		_world.remove_object(_tile)
		_state.player.inventory.add(SEEDS[tree], 2)
		_hold(SEEDS[tree])
		assert_eq(_state.use_facing_tile(), GameState.Use.PLANT, tree)
		assert_eq(_world.object_at(_tile).type, WorldObjectTypes.SAPLING)
		assert_eq(_world.object_at(_tile).state["tree"], str(tree))
		_sleep_days(4)
		assert_eq(_world.object_at(_tile).type, tree)
		_state.player.inventory.remove(SEEDS[tree], 1)


func test_a_seed_is_not_planted_on_soil_and_crop_seeds_not_on_grass() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_state.player.inventory.add(ItemTypes.ACORN, 1)
	_hold(ItemTypes.ACORN)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_at(_tile), GameState.Use.NOTHING)


func test_a_hand_picks_the_seed_of_the_species_off_a_planted_sapling() -> void:
	_place(WorldObjectTypes.SAPLING, "spruce")
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), GameState.Use.FORAGE)
	assert_eq(_dropped(ItemTypes.SPRUCE_CONE), 1)
	assert_eq(_dropped(ItemTypes.ACORN), 0)
