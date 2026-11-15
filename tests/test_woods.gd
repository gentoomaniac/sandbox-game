extends GutTest
## The woods of the generator: compact patches with an edge and clearings, and no lone trees.

const SEEDS: Array[int] = [1, 42, 7]
## The area sampled: a stretch of the Geest north and south of the river, east of the coast.
const AREA := Rect2i(-100, -500, 700, 1000)
const SAMPLE_STEP := 3
const TREE_TYPES: Array[StringName] = [
	WorldObjectTypes.OAK,
	WorldObjectTypes.BEECH,
	WorldObjectTypes.BIRCH,
	WorldObjectTypes.ALDER,
	WorldObjectTypes.WILLOW,
	WorldObjectTypes.PINE,
	WorldObjectTypes.SPRUCE,
]
const MARSH_REACH := 36.0
## A wood's outline is pushed about by the warp (8 tiles in x and y). That moves a tile's distance
## from the river by its y part and its x part times the river's slope, which is under 2: so only
## tiles this much deeper in the marsh are sure to have no wood.
const WARP_RIVER_DISTANCE := 8.0 * 3.0


## Every sampled tile of grass: {"pos": Vector2i, "river_distance": float}.
func _grass_samples(generator: WorldGenerator) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for y in range(AREA.position.y, AREA.end.y, SAMPLE_STEP):
		for x in range(AREA.position.x, AREA.end.x, SAMPLE_STEP):
			var pos := Vector2i(x, y)
			if generator.terrain_at(pos) == Tile.Terrain.GRASS:
				samples.append({"pos": pos, "river_distance": generator._river_distance(pos)})
	return samples


func test_about_a_sixth_of_the_geest_is_wood() -> void:
	for world_seed in SEEDS:
		var generator := WorldGenerator.new(world_seed)
		var geest := 0
		var wood := 0
		for sample in _grass_samples(generator):
			if sample["river_distance"] < WorldGenerator.RIVER_HALF_WIDTH + MARSH_REACH + 10.0:
				continue
			geest += 1
			if generator.is_forest(sample["pos"]):
				wood += 1
		assert_between(float(wood) / geest, 0.1, 0.2, "wood share of seed %d" % world_seed)


func test_trees_stand_in_woods_only() -> void:
	for world_seed in SEEDS:
		var generator := WorldGenerator.new(world_seed)
		var trees := 0
		for sample in _grass_samples(generator):
			var pos: Vector2i = sample["pos"]
			if generator.object_type_at(pos, Tile.Terrain.GRASS) in TREE_TYPES:
				trees += 1
				assert_true(
					generator.is_forest(pos), "a lone tree at %s, seed %d" % [pos, world_seed]
				)
		assert_gt(trees, 200, "trees in seed %d" % world_seed)


func test_the_marsh_has_no_woods() -> void:
	for world_seed in SEEDS:
		var generator := WorldGenerator.new(world_seed)
		for sample in _grass_samples(generator):
			var is_deep_in_the_marsh: bool = (
				sample["river_distance"]
				< (
					WorldGenerator.RIVER_HALF_WIDTH
					+ WorldGenerator.FLOODPLAIN_WIDTH
					+ MARSH_REACH
					- WARP_RIVER_DISTANCE
				)
			)
			if is_deep_in_the_marsh:
				assert_false(generator.is_forest(sample["pos"]), "a wood at %s" % sample["pos"])


func test_clearings_cut_holes_into_woods() -> void:
	var generator := WorldGenerator.new(SEEDS[0])
	var layout := WoodLayout.new(SEEDS[0], LandscapeRules.default_rules())
	var clearings := 0
	for sample in _grass_samples(generator):
		var pos: Vector2i = sample["pos"]
		if generator.is_forest(pos) and layout.is_clearing_at(pos):
			clearings += 1
			assert_false(
				generator.object_type_at(pos, Tile.Terrain.GRASS) in TREE_TYPES,
				"a tree in a clearing at %s" % pos
			)
	assert_gt(clearings, 20, "clearings in the woods")


func test_woods_are_the_same_for_the_same_seed_and_differ_between_seeds() -> void:
	var first := WorldGenerator.new(SEEDS[0])
	var again := WorldGenerator.new(SEEDS[0])
	var other := WorldGenerator.new(SEEDS[1])
	var differing := 0
	for y in range(0, 200, 2):
		for x in range(0, 200, 2):
			var pos := Vector2i(x, y)
			assert_eq(first.is_forest(pos), again.is_forest(pos))
			if first.is_forest(pos) != other.is_forest(pos):
				differing += 1
	assert_gt(differing, 100, "another seed has other woods")
