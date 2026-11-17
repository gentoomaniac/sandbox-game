class_name WorldBuildings
extends RefCounted
## The buildings of a world and the tiles they cover. Buildings are the player's work and must
## outlive the chunks they stand on, and one can cross a chunk border, so they live here and not in
## chunks.
##
## It holds no World: what a placement rule has to ask the world about its ground and objects is
## given per call.

## Why a footprint tile can't be built on.
enum Blocked {
	## Water, wetland or floodplain, or the tile is not loaded.
	TERRAIN,
	## A world object or a building is on it.
	OCCUPIED,
}

var _buildings: Array[Building] = []
var _building_by_tile: Dictionary[Vector2i, Building] = {}


func add(building: Building) -> void:
	_buildings.append(building)
	for pos in building.tiles():
		_building_by_tile[pos] = building


func remove(building: Building) -> void:
	assert(_buildings.has(building), "Not a building of this world")
	_buildings.erase(building)
	for tile in building.tiles():
		_building_by_tile.erase(tile)


func all() -> Array[Building]:
	return _buildings.duplicate()


## The tiles buildings cover, doors included, as keys of a copy that shares nothing but the
## buildings themselves (see TravelSnapshot).
func tiles() -> Dictionary:
	return _building_by_tile.duplicate()


## The building whose footprint covers a tile, or null.
func at(world_pos: Vector2i) -> Building:
	return _building_by_tile.get(world_pos)


## Whether a tile is the one just below a building's door, which has to stay free to walk through.
func is_in_front_of_door(world_pos: Vector2i) -> bool:
	var building_above := at(world_pos + Vector2i.UP)
	return building_above != null and building_above.door_tile() == world_pos + Vector2i.UP


## The footprint tiles of `world` that stop a building from being placed, with the reason for
## each. Empty if it can be placed. Must agree with `World.is_buildable`.
func placement_blockers(
	world: World, building_type: StringName, origin: Vector2i
) -> Dictionary[Vector2i, Blocked]:
	var blockers: Dictionary[Vector2i, Blocked] = {}
	for pos in Building.footprint_tiles(building_type, origin):
		var tile := world.tile_at(pos)
		if tile == null or not tile.is_buildable():
			blockers[pos] = Blocked.TERRAIN
		elif world.is_in_the_way(pos) or at(pos) != null:
			blockers[pos] = Blocked.OCCUPIED
	# The player has to be able to stand in front of the door, to go in and to come out.
	var door_offset: Vector2i = BuildingTypes.TYPES[building_type]["door_offset"]
	var front := origin + door_offset + Vector2i.DOWN
	if not world.is_walkable(front):
		var is_blocked_by_object := (
			world.tile_at(front) != null and world.tile_at(front).is_walkable()
		)
		blockers[front] = Blocked.OCCUPIED if is_blocked_by_object else Blocked.TERRAIN
	return blockers


## The buildings made data, for `WorldSave.dict_of`.
func snapshot() -> Array[Dictionary]:
	var buildings_data: Array[Dictionary] = []
	for building in _buildings:
		buildings_data.append(building.to_dict())
	return buildings_data


## Takes the buildings of a save (see `snapshot`).
func load_array(buildings_data: Array) -> void:
	for building_data: Dictionary in buildings_data:
		add(Building.from_dict(building_data))
