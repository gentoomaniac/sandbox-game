extends GutTest
## A bee keeps to the flowers: it flies from one in bloom to another nearby, and off when there
## is none left near it. The meadow is placed by hand on the decorations of a world view.

const SEED := 3
const SUMMER := 45
const WINTER := 105

var _wildlife: WildlifeView


func before_each() -> void:
	_wildlife = WildlifeView.new()
	autofree(_wildlife)
	_wildlife.rules = WildlifeRules.default_rules()
	_wildlife.world_view = WorldView.new()
	add_child_autofree(_wildlife.world_view)
	_wildlife.world_view.add_child(_wildlife.ground)
	_wildlife.world_view.decorations.show_world(World.new(SEED))


## Lays a meadow of grass tiles around the origin on a day.
func _meadow(day: int) -> void:
	var decorations := _wildlife.world_view.decorations
	decorations.day = day
	for y in range(-20, 20):
		for x in range(-20, 20):
			decorations.place(Vector2i(x, y), TerrainTileset.Layer.GRASS, false)


## A bee hovering at a tile, done with its hovering.
func _bee_at(tile: Vector2i) -> Bee:
	var bee := Bee.new()
	bee.wildlife = _wildlife
	bee.position = TerrainTileset.tile_centre(tile)
	add_child_autofree(bee)
	bee._state_time = 100.0
	return bee


func test_a_bee_flies_on_to_a_flower_near_it() -> void:
	_meadow(SUMMER)
	var flowers := _wildlife.flowers_near(Vector2.ZERO, 6)
	assert_gt(flowers.size(), 1, "the meadow flowers")
	var bee := _bee_at(flowers[0])
	bee._update(0.1)
	assert_eq(bee._state, Bee.TRAVEL)
	assert_true(_wildlife.has_flower(bee._flower), "to a flower")
	assert_lte(
		Vector2(bee._flower - flowers[0]).length(), Bee.FLOWER_REACH_TILES * sqrt(2.0), "nearby"
	)


func test_a_bee_with_no_flower_near_it_flies_off() -> void:
	_meadow(WINTER)
	var bee := _bee_at(Vector2i.ZERO)
	bee._update(0.1)
	assert_eq(bee._state, Bee.LEAVE)
