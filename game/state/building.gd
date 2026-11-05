class_name Building
extends RefCounted
## One placed building. Its kind is data in BuildingTypes; customisation will be added
## here later.

var type: StringName
## World tile position of the top left tile of the footprint.
var origin: Vector2i
## The inside, made from the building type's map the first time someone enters. It is kept
## here so what changes inside stays. It is not in the world's edits, so a save must store it
## with the building.
var interior: Interior


func _init(building_type: StringName, origin_tile: Vector2i) -> void:
	assert(BuildingTypes.TYPES.has(building_type), "Unknown building type: %s" % building_type)
	type = building_type
	origin = origin_tile


## The world positions of the tiles of a footprint placed at `origin_tile`.
static func footprint_tiles(building_type: StringName, origin_tile: Vector2i) -> Array[Vector2i]:
	var size: Vector2i = BuildingTypes.TYPES[building_type]["footprint"]
	var tiles: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			tiles.append(origin_tile + Vector2i(x, y))
	return tiles


func tiles() -> Array[Vector2i]:
	return footprint_tiles(type, origin)


func door_tile() -> Vector2i:
	return origin + BuildingTypes.TYPES[type]["door_offset"]
