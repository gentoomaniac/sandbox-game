class_name Building
extends RefCounted
## One placed building. Its kind and its style are data in BuildingTypes.

var type: StringName
## Which of its building's looks it has (see BuildingTypes `styles`); &"" is the building's own.
var style: StringName
## World tile position of the top left tile of the footprint.
var origin: Vector2i
## The inside, made from the building type's map the first time someone enters. It is kept
## here so what changes inside stays. It is not in the world's edits, so a save must store it
## with the building.
var interior: Interior


func _init(building_type: StringName, origin_tile: Vector2i, building_style := &"") -> void:
	assert(BuildingTypes.TYPES.has(building_type), "Unknown building type: %s" % building_type)
	type = building_type
	origin = origin_tile
	style = building_style


## The inside, made from the building type's map the first time it is needed (someone goes in, or a
## hen lays an egg in it).
func inside() -> Interior:
	if interior == null:
		interior = InteriorLoader.load_interior(BuildingTypes.TYPES[type]["interior_map"])
	return interior


## Gives it the inside of the map at `map_path` (a room of the size and door of its type's
## default, see VillagerRules) instead of the type's default: the inside a villager's house has.
## The inside is replaced only if it is still the untouched default, or not made yet. It stays
## the same object (the player's home map may be it), so its content is copied.
func furnish_from(map_path: String) -> void:
	if interior == null:
		interior = InteriorLoader.load_interior(map_path)
	elif can_be_furnished():
		interior.copy_from(InteriorLoader.load_interior(map_path))


## Whether `furnish_from` would give it another inside: it has none yet, or still the type's
## default, untouched.
func can_be_furnished() -> bool:
	var default_map: String = BuildingTypes.TYPES[type]["interior_map"]
	return (
		interior == null
		or interior.to_dict() == InteriorLoader.load_interior(default_map).to_dict()
	)


## The entry of its style in BuildingTypes: its name, pictures and costs.
func type_data() -> Dictionary:
	return BuildingTypes.of(type, style)


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


## The middle of its footprint, in tiles.
func centre() -> Vector2:
	var size: Vector2i = BuildingTypes.TYPES[type]["footprint"]
	return Vector2(origin) + Vector2(size) / 2.0


func door_tile() -> Vector2i:
	return origin + BuildingTypes.TYPES[type]["door_offset"]


## The middle of the tile in front of the door: where someone stands who comes to the building.
func yard() -> Vector2:
	return Vector2(door_tile() + Vector2i.DOWN) + Vector2(0.5, 0.5)


## Whether it has an inside to go into (the bell frame has none).
func has_inside() -> bool:
	return BuildingTypes.TYPES[type]["interior_map"] != ""


func to_dict() -> Dictionary:
	return {
		"type": str(type),
		"style": str(style),
		"origin": SaveCodec.vector_to_json(origin),
		"interior": null if interior == null else interior.to_dict(),
	}


static func from_dict(data: Dictionary) -> Building:
	var building := Building.new(
		StringName(data["type"]),
		SaveCodec.vector_from_json(data["origin"]),
		StringName(data["style"])
	)
	if data["interior"] != null:
		building.interior = Interior.from_dict(data["interior"])
	return building
