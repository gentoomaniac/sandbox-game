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
## The tiles of the lanes and of the town square that wear (grass), which the village keeps worn
## to a path (see `World.end_wear_day`).
var kept_worn_tiles: Array[Vector2i] = []
## A tile in the middle of each field the village keeps, where a villager goes to tend it.
var field_spots: Array[Vector2i] = []
## The origins of the buildings the village put up.
var building_origins: Array[Vector2i] = []
## Whether the villagers of the village were spawned (they are, once).
var is_populated := false


## Whether the tile is on the village's land.
func is_land(tile: Vector2i) -> bool:
	return area.has_point(tile)


## Whether the village put up the building.
func has_building(building: Building) -> bool:
	return building_origins.has(building.origin)


## What the console says of the village to someone standing on `tile`: where it lies, the way to
## its meeting place and what it holds.
func describe_from(tile: Vector2i) -> Array[String]:
	var offset := area.get_center() - tile
	var where := "You are on its land"
	if not is_land(tile):
		where = (
			"It lies about %d tiles %s, %d %s"
			% [
				absi(offset.x),
				"east" if offset.x > 0 else "west",
				absi(offset.y),
				"south" if offset.y > 0 else "north",
			]
		)
	return [
		"%s. %s." % [village_name, where],
		(
			"Its land is %d by %d tiles with %d buildings; the town square is at %d, %d (tp %d %d)."
			% [
				area.size.x,
				area.size.y,
				building_origins.size(),
				meeting_spot.x,
				meeting_spot.y,
				meeting_spot.x,
				meeting_spot.y,
			]
		),
	]


func to_dict() -> Dictionary:
	return {
		"name": village_name,
		"area": SaveCodec.rect_to_json(area),
		"meeting_spot": SaveCodec.vector_to_json(meeting_spot),
		"square": SaveCodec.rect_to_json(square),
		"mill_spot": SaveCodec.rect_to_json(mill_spot),
		"kept_worn_tiles": kept_worn_tiles.map(SaveCodec.vector_to_json),
		"field_spots": field_spots.map(SaveCodec.vector_to_json),
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
	for entry: Array in data["kept_worn_tiles"]:
		village.kept_worn_tiles.append(SaveCodec.vector_from_json(entry))
	for entry: Array in data["field_spots"]:
		village.field_spots.append(SaveCodec.vector_from_json(entry))
	for entry: Array in data["building_origins"]:
		village.building_origins.append(SaveCodec.vector_from_json(entry))
	village.is_populated = data["is_populated"]
	return village
