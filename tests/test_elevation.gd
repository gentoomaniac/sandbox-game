extends GutTest
## The height of the land (storm surge, #103): the Geest rises inland and the Koog lies lowest.

const SEED := 42
const ROW := 0

var _generator := WorldGenerator.new(SEED)
var _elevation := Elevation.new(SEED, _generator)


func _first_land() -> Vector2i:
	return Vector2i(_generator.first_land_x(ROW), ROW)


func test_the_same_seed_gives_the_same_height() -> void:
	var again := Elevation.new(SEED, WorldGenerator.new(SEED))
	var tile := _first_land() + Vector2i(10, 0)
	assert_eq(_elevation.at(tile, Tile.Terrain.GRASS), again.at(tile, Tile.Terrain.GRASS))


func test_grass_rises_inland_up_to_the_geest() -> void:
	var rules := LandscapeRules.default_rules()
	var at_dyke := _elevation.at(_first_land(), Tile.Terrain.GRASS)
	var far_inland := _elevation.at(_first_land() + Vector2i(400, 0), Tile.Terrain.GRASS)
	var noise: float = rules.value("surge", "noise") + rules.value("surge", "fine_noise")
	assert_almost_eq(at_dyke, rules.value("surge", "land_at_dyke"), noise)
	assert_almost_eq(far_inland, rules.value("surge", "land_top"), noise)


func test_the_koog_lies_below_the_weakest_surge_at_the_dyke_and_below_the_geest_at_its_edge(
) -> void:
	var rules := LandscapeRules.default_rules()
	var weakest_surge := 1.6
	var koog_edge := _first_land() + Vector2i(int(rules.value("marsh", "reach")), 0)
	assert_lt(_elevation.at(_first_land(), Tile.Terrain.GRASS), weakest_surge)
	assert_lt(_elevation.at(koog_edge, Tile.Terrain.GRASS), rules.value("surge", "land_top") - 1.0)


func test_each_terrain_has_its_own_base() -> void:
	var tile := _first_land()
	var rules := LandscapeRules.default_rules()
	var noise: float = rules.value("surge", "noise") + rules.value("surge", "fine_noise")
	assert_almost_eq(_elevation.at(tile, Tile.Terrain.MUD), 0.0, noise)
	assert_almost_eq(_elevation.at(tile, Tile.Terrain.SALT_MARSH), 0.8, noise)
	assert_almost_eq(_elevation.at(tile, Tile.Terrain.WARFT), 3.6, noise)


func test_the_warft_lies_above_the_highest_surge() -> void:
	var tile := _first_land()
	assert_gt(_elevation.at(tile, Tile.Terrain.WARFT), 3.2)


func test_the_floors_of_houses_never_flood() -> void:
	assert_eq(_elevation.at(Vector2i.ZERO, Tile.Terrain.FLOOR), Elevation.NEVER_FLOODED)


func test_the_fine_noise_bends_the_edge_of_the_water() -> void:
	var rules := LandscapeRules.default_rules()
	var first := _first_land() + Vector2i(30, 0)
	var steps := 0
	for x in 40:
		var here := _elevation.at(first + Vector2i(x, 0), Tile.Terrain.GRASS)
		var next := _elevation.at(first + Vector2i(x + 1, 0), Tile.Terrain.GRASS)
		steps += int(absf(next - here) > rules.value("surge", "land_rise") * 2.0)
	assert_gt(steps, 10, "the ground between neighbours is not an even slope")
