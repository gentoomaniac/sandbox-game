extends WildlifeCase
## The birds of the coast in the view, on a stretch of coast laid around the middle of the view:
## salt marsh, then tidal mud, then the sea, from east to west.

## On day 1 the tide is high at midnight and low half a tide later (see Tide).
const HIGH_WATER := 0
const LOW_WATER := 373
## The coast laid around the middle of the view, in tiles from its middle tile: the sea west of
## SEA_EAST, the salt marsh east of MARSH_WEST, the mud between.
const COAST_REACH := 12
const SEA_EAST := -3
const MARSH_WEST := 4

var _middle: Vector2i


func before_each() -> void:
	super()
	_middle = Vector2i((VIEW_CENTRE / TerrainTileset.TILE_SIZE).floor())
	for y in range(-COAST_REACH, COAST_REACH + 1):
		for x in range(-COAST_REACH, COAST_REACH + 1):
			var terrain := Tile.Terrain.MUD
			if x < SEA_EAST:
				terrain = Tile.Terrain.SEA
			elif x >= MARSH_WEST:
				terrain = Tile.Terrain.SALT_MARSH
			_state.world.set_terrain(_middle + Vector2i(x, y), terrain)
			_state.world.remove_object(_middle + Vector2i(x, y))
	_state.clock.minute_of_day = LOW_WATER


## The middle of a tile of the coast, `x` tiles east of the view's middle tile.
func _point(x: int, y := 0) -> Vector2:
	return TerrainTileset.tile_centre(_middle + Vector2i(x, y))


func test_nothing_stands_on_the_mud_while_the_tide_is_in() -> void:
	var mud := _point(0)
	assert_true(_wildlife.can_stand(mud), "dry at low water")
	assert_false(_wildlife.is_water(mud))
	_state.clock.minute_of_day = HIGH_WATER
	assert_false(_wildlife.can_stand(mud), "under at high water")
	assert_true(_wildlife.is_water(mud))
	assert_true(_wildlife.can_stand(_point(MARSH_WEST)), "the salt marsh stays dry")
	assert_true(_wildlife.is_water(_point(SEA_EAST - 1)), "the sea")
