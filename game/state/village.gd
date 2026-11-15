class_name Village
extends RefCounted
## The record of the village in a world (`World.village`, null where there is none): the land it
## owns and what it put on it, in world tiles. It is made once, when a new game builds the village
## (see VillageBuilder), and saved with the world. What the village is like is in VillagePlan; this
## is what stays of it to ask of.

var village_name := ""
## The village's land.
var area := Rect2i()
## The middle of the town square, where the villagers meet.
var meeting_spot := Vector2i.ZERO
## The town square, kept free for a future market.
var square := Rect2i()
## The free spot for the post mill.
var mill_spot := Rect2i()
## The tiles of the village's lanes.
var lane_tiles: Array[Vector2i] = []
## The origins of the buildings the village put up.
var building_origins: Array[Vector2i] = []
## Whether the villagers of the village were spawned (they are, once).
var is_populated := false


func to_dict() -> Dictionary:
	return {
		"name": village_name,
		"area": SaveCodec.rect_to_json(area),
		"meeting_spot": SaveCodec.vector_to_json(meeting_spot),
		"square": SaveCodec.rect_to_json(square),
		"mill_spot": SaveCodec.rect_to_json(mill_spot),
		"lane_tiles": lane_tiles.map(SaveCodec.vector_to_json),
		"building_origins": building_origins.map(SaveCodec.vector_to_json),
		"is_populated": is_populated,
	}


static func from_dict(data: Dictionary) -> Village:
	var village := Village.new()
	village.village_name = data["name"]
	village.area = SaveCodec.rect_from_json(data["area"])
	village.meeting_spot = SaveCodec.vector_from_json(data["meeting_spot"])
	village.square = SaveCodec.rect_from_json(data["square"])
	village.mill_spot = SaveCodec.rect_from_json(data["mill_spot"])
	for entry: Array in data["lane_tiles"]:
		village.lane_tiles.append(SaveCodec.vector_from_json(entry))
	for entry: Array in data["building_origins"]:
		village.building_origins.append(SaveCodec.vector_from_json(entry))
	village.is_populated = data["is_populated"]
	return village
