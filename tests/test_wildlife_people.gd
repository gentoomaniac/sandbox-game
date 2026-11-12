extends WildlifeCase
## Wild animals never stand on a building tile, the door included, whether they stand, spawn,
## settle or move.

const MIDSUMMER := 45
const TILE := float(TerrainTileset.TILE_SIZE)
## Kinds that fly or stand on roofs by design: they are not on the ground of a building tile.
const OFF_THE_GROUND: Array[StringName] = [
	WildlifeRules.ROOF_STORK,
	WildlifeRules.BEE,
	WildlifeRules.BUTTERFLY,
	WildlifeRules.FIREFLY,
	WildlifeRules.FLOCK,
	WildlifeRules.FLYING_GEESE,
	WildlifeRules.TERN,
]


func before_each() -> void:
	super.before_each()
	_state.clock.day = MIDSUMMER
	_state.weather_override = &"clear"


## Houses on a row of lots around the view centre, wherever they can be placed.
func _houses_around_the_view() -> Array[Building]:
	var houses: Array[Building] = []
	var centre := Vector2i((VIEW_CENTRE / TILE).floor())
	for y in range(-10, 11, 5):
		for x in range(-14, 15, 7):
			var house := _state.world.place_building(BuildingTypes.KATE, centre + Vector2i(x, y))
			if house != null:
				houses.append(house)
	return houses


func test_no_animal_can_stand_on_a_building_tile_the_door_included() -> void:
	var houses := _houses_around_the_view()
	assert_gt(houses.size(), 0, "houses placed")
	for house in houses:
		for tile in house.tiles():
			var point := TerrainTileset.tile_centre(tile)
			for kind in WildlifeRules.KINDS:
				assert_false(_wildlife.can_stand(point, kind), "%s on %s" % [kind, tile])
		var door := TerrainTileset.tile_centre(house.door_tile())
		assert_false(_wildlife.can_stand(door, WildlifeRules.MOUSE), "a mouse in the door")


func test_no_animal_spawns_or_settles_on_a_building_tile() -> void:
	var houses := _houses_around_the_view()
	assert_gt(houses.size(), 0, "houses placed")
	var checked := 0
	for hour in [4, 8, 12, 17, 21, 23]:
		_state.clock.set_time(hour, 0)
		_wildlife.settle()
		for animal in _wildlife._animals:
			if animal.kind in OFF_THE_GROUND or animal is Stork and animal.is_nest_parent:
				continue
			checked += 1
			var tile := Vector2i((animal.position / TILE).floor())
			assert_null(_state.world.building_at(tile), "%s on a building" % animal.kind)
	assert_gt(checked, 0, "animals settled")


func test_animals_stay_off_buildings_while_they_move() -> void:
	_houses_around_the_view()
	_state.clock.set_time(12, 0)
	_wildlife.settle()
	for animal in _wildlife._animals.duplicate():
		if animal.kind in OFF_THE_GROUND or animal is Stork and animal.is_nest_parent:
			continue
		_run(animal, 30.0)
		var tile := Vector2i((animal.position / TILE).floor())
		assert_null(_state.world.building_at(tile), "%s on a building" % animal.kind)
