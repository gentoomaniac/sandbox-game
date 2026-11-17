extends GutTest
## Where the land puts the dead and the half-dead trees (issue #102): of the kind of the trees
## around, about as rare as the single dead tree was.

const SEED := 42
const AREA := Rect2i(-160, -160, 320, 320)
const OLD_DEAD_TREE_CHANCE := 0.0015


func test_the_land_puts_dead_and_half_dead_trees_of_the_kind_of_the_trees_around() -> void:
	var generator := WorldGenerator.new(SEED)
	var dead := 0
	var half_dead := 0
	var kinds := {}
	var grass := 0
	for y in range(AREA.position.y, AREA.end.y):
		for x in range(AREA.position.x, AREA.end.x):
			var pos := Vector2i(x, y)
			var terrain := generator.terrain_at(pos)
			grass += int(terrain == Tile.Terrain.GRASS)
			var type := generator.object_type_at(pos, terrain)
			for kind in WorldObjectSnags.KINDS:
				if type == WorldObjectSnags.dead_type(kind):
					dead += 1
					kinds[kind] = true
					assert_eq(
						kind,
						generator._tree_type_at(
							pos,
							generator._river_distance(pos),
							PositionHash.unit(pos, generator._variety_roll_seed)
						)
					)
				elif type == WorldObjectSnags.half_dead_type(kind):
					half_dead += 1
					kinds[kind] = true
			assert_ne(type, WorldObjectTypes.DEAD_TREE, "new worlds have no single dead tree")
	assert_gt(dead, half_dead, "more dead than half dead")
	assert_gt(half_dead, 0)
	assert_gte(kinds.size(), 5, "kinds with a snag: %s" % [kinds.keys()])
	var rate := float(dead + half_dead) / grass
	assert_between(
		rate, OLD_DEAD_TREE_CHANCE * 0.8, WorldGenerator.DEAD_TREE_NEAR_WETLAND_CHANCE * 0.5
	)
	var half_dead_share := float(half_dead) / (dead + half_dead)
	assert_between(
		half_dead_share, WorldGenerator.HALF_DEAD_SHARE - 0.1, WorldGenerator.HALF_DEAD_SHARE + 0.1
	)
