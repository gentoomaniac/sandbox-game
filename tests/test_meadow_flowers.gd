extends GutTest
## DecorationView's meadow flowers: where they grow, in which seasons, and that the wildlife
## finds them only where they bloom. Places tiles by hand, with the layer given.

const SEED := 3
const EARLY_SPRING := 6
const LATE_SPRING := 25
const SUMMER := 45
const AUTUMN := 80
const WINTER := 105
const GRASS := TerrainTileset.Layer.GRASS

var _tileset := TerrainTileset.new()
var _view: DecorationView


func before_each() -> void:
	_view = DecorationView.new(_tileset)
	add_child_autofree(_view)
	var world := World.new(SEED)
	_view.show_world(world)
	_view.ground_cover = GroundCover.new(world)


## Places a square of tiles of a layer on a day and returns those with a flower in bloom.
func _flowers_on(layer: TerrainTileset.Layer, day: int) -> Array[Vector2i]:
	_view.day = day
	var area := Rect2i(0, -60, 60, 60)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			_view.place(Vector2i(x, y), layer, false)
	var tile_size := TerrainTileset.TILE_SIZE
	return _view.flower_tiles_within(Rect2(area.position * tile_size, area.size * tile_size))


func test_meadows_flower_in_summer() -> void:
	var flowers := _flowers_on(GRASS, SUMMER)
	assert_gt(flowers.size(), 3600 / 10, "a tenth of the meadow or more")
	for tile in flowers:
		var cell := _view._decorations.get_cell_atlas_coords(tile)
		assert_eq(cell.y, TerrainTileset.FLOWER_ROW, "a meadow flower at %s" % tile)


func test_no_flowers_on_fields_or_water() -> void:
	for layer in [TerrainTileset.Layer.SOIL, TerrainTileset.Layer.WATER]:
		for day in [LATE_SPRING, SUMMER]:
			assert_eq(_flowers_on(layer, day).size(), 0, "layer %d on day %d" % [layer, day])


func test_no_flowers_in_winter_and_fewer_in_early_spring_and_autumn() -> void:
	assert_eq(_flowers_on(GRASS, WINTER).size(), 0)
	var summer := _flowers_on(GRASS, SUMMER).size()
	assert_lt(_flowers_on(GRASS, EARLY_SPRING).size() * 3, summer)
	assert_lt(_flowers_on(GRASS, AUTUMN).size() * 3, summer)


func test_a_flower_under_snow_is_no_flower_to_visit() -> void:
	var world := World.new(SEED)
	for chunk in [Vector2i(0, -2), Vector2i(1, -2), Vector2i(0, -1), Vector2i(1, -1)]:
		world.add_chunk(Chunk.new(chunk))
	_view.show_world(world)
	_view.ground_cover = GroundCover.new(world)
	assert_gt(_flowers_on(GRASS, SUMMER).size(), 0, "in bloom without snow")
	_view.ground_cover.set_weather(0.0, 1.0, 0.0, 0.0)
	assert_eq(_flowers_on(GRASS, SUMMER).size(), 0, "none under a full snow cover")


func test_no_flower_under_an_object() -> void:
	var flowers := _flowers_on(GRASS, SUMMER)
	var tile := flowers[0]
	_view.place(tile, GRASS, true)
	assert_false(_view.has_flower(tile))
	assert_eq(_view._decorations.get_cell_source_id(tile), -1)


func test_the_first_flowers_of_spring_are_small_and_summer_is_full() -> void:
	var small_share := func(day: int) -> float:
		var flowers := _flowers_on(GRASS, day)
		var small := flowers.filter(
			func(tile: Vector2i) -> bool:
				var column := _view._decorations.get_cell_atlas_coords(tile).x
				return column % TerrainTileset.FLOWER_VARIANTS == TerrainTileset.FlowerVariant.SMALL
		)
		return float(small.size()) / flowers.size()
	assert_gt(small_share.call(EARLY_SPRING), 0.5)
	assert_lt(small_share.call(SUMMER), 0.25)


func test_the_flowers_change_with_the_season() -> void:
	var species_on := func(day: int) -> Dictionary:
		var seen := {}
		for tile in _flowers_on(GRASS, day):
			var column := _view._decorations.get_cell_atlas_coords(tile).x
			seen[column / TerrainTileset.FLOWER_VARIANTS] = true
		return seen
	var spring: Dictionary = species_on.call(LATE_SPRING)
	var summer: Dictionary = species_on.call(55)
	var dandelion := TerrainTileset.FLOWER_SPECIES.find(&"dandelion")
	var knapweed := TerrainTileset.FLOWER_SPECIES.find(&"knapweed")
	assert_true(spring.has(dandelion) and not spring.has(knapweed))
	assert_true(summer.has(knapweed) and not summer.has(dandelion))
