extends GutTest
## Where wildlife may appear (habitat, the ring around the view) and when it reacts to the player.

const SEED := 1

var _rules := WildlifeRules.default_rules()


func test_deer_need_a_forest_and_squirrels_trees() -> void:
	assert_false(_rules.is_habitat(WildlifeRules.DEER, Tile.Terrain.GRASS, 0))
	assert_true(_rules.is_habitat(WildlifeRules.DEER, Tile.Terrain.GRASS, 10))
	assert_false(_rules.is_habitat(WildlifeRules.SQUIRREL, Tile.Terrain.GRASS, 0))
	assert_true(_rules.is_habitat(WildlifeRules.SQUIRREL, Tile.Terrain.GRASS, 3))
	assert_false(_rules.is_habitat(WildlifeRules.DEER, Tile.Terrain.WATER, 10))


func test_ground_animals_stay_off_water() -> void:
	for kind in [WildlifeRules.BIRD, WildlifeRules.RABBIT, WildlifeRules.BUTTERFLY]:
		assert_false(_rules.is_habitat(kind, Tile.Terrain.WATER, 0), "%s on water" % kind)
		assert_true(_rules.is_habitat(kind, Tile.Terrain.GRASS, 0), "%s on grass" % kind)


func test_trees_are_counted_around_a_tile() -> void:
	var world := World.new(SEED)
	world.add_chunk(WorldGenerator.new(SEED).generate_chunk(Vector2i(0, 0)))
	var origin := Vector2i(8, 8)
	var near := WildlifeRules.count_trees(world, origin, 2)
	var far := WildlifeRules.count_trees(world, origin, 7)
	assert_gte(far, near)
	assert_eq(WildlifeRules.count_trees(world, origin, 0), _tree_at(world, origin))


func _tree_at(world: World, pos: Vector2i) -> int:
	var object := world.object_at(pos)
	return 1 if object != null and WildlifeRules.TREE_TYPES.has(object.type) else 0


func test_spawn_points_lie_outside_the_view_or_at_its_edge() -> void:
	var view := Rect2(Vector2(100, 100), Vector2(320, 180))
	var player := view.get_center()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var inset := _rules.general("spawn_inset_tiles") * WildlifeRules.TILE_SIZE
	var margin := _rules.general("spawn_margin_tiles") * WildlifeRules.TILE_SIZE
	for _i in 300:
		var point := _rules.random_ring_point(view, rng)
		assert_true(view.grow(margin).has_point(point), "not beyond the margin")
		assert_false(view.grow(-inset).has_point(point), "not deep inside the view")
		assert_true(_rules.is_spawn_point(point, view, player))


func test_nothing_spawns_on_the_player_or_inside_the_view() -> void:
	var view := Rect2(Vector2(0, 0), Vector2(160, 90))
	assert_false(_rules.is_spawn_point(view.get_center(), view, view.get_center()))
	assert_false(_rules.is_spawn_point(Vector2(1000, 1000), view, view.get_center()))
	assert_true(_rules.is_spawn_point(Vector2(-20, 40), view, view.get_center()))
	# At the edge, but the player stands right there.
	assert_false(_rules.is_spawn_point(Vector2(-20, 40), view, Vector2(-20, 41)))


func test_animals_far_from_the_view_vanish() -> void:
	var view := Rect2(Vector2(0, 0), Vector2(320, 180))
	assert_false(_rules.is_beyond_view(Vector2(-50, 50), view))
	assert_true(_rules.is_beyond_view(Vector2(-1000, 50), view))


# --- Reacting to the player ---


func test_birds_and_rabbits_flee_at_their_distance() -> void:
	assert_eq(_rules.reaction(WildlifeRules.BIRD, 2.9), WildlifeRules.Reaction.FLEE)
	assert_eq(_rules.reaction(WildlifeRules.BIRD, 3.5), WildlifeRules.Reaction.NONE)
	assert_eq(_rules.reaction(WildlifeRules.RABBIT, 3.9), WildlifeRules.Reaction.FLEE)
	assert_eq(_rules.reaction(WildlifeRules.RABBIT, 4.5), WildlifeRules.Reaction.NONE)


func test_deer_look_up_at_6_tiles_and_bound_away_at_4() -> void:
	assert_eq(_rules.reaction(WildlifeRules.DEER, 7.0), WildlifeRules.Reaction.NONE)
	assert_eq(_rules.reaction(WildlifeRules.DEER, 5.0), WildlifeRules.Reaction.ALERT)
	assert_eq(_rules.reaction(WildlifeRules.DEER, 3.5), WildlifeRules.Reaction.FLEE)


func test_insects_ignore_the_player() -> void:
	assert_eq(_rules.reaction(WildlifeRules.BEE, 0.5), WildlifeRules.Reaction.NONE)
	assert_eq(_rules.reaction(WildlifeRules.BUTTERFLY, 0.5), WildlifeRules.Reaction.NONE)
