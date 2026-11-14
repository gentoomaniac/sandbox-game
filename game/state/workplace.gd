class_name Workplace
extends RefCounted
## Where a villager works: a building, or a spot with a name where there is no building to work
## in (the landing at the sluice, a field). A routine asks `spot` where to send them.

## The building they work in, or null for a spot.
var building: Building
## What a spot is called, such as "the landing at the sluice"; "" for a building.
var spot_name := ""
## The tile of a spot.
var spot_tile := Vector2i.ZERO


static func of_building(workplace_building: Building) -> Workplace:
	var workplace := Workplace.new()
	workplace.building = workplace_building
	return workplace


static func of_spot(name_of_spot: String, tile: Vector2i) -> Workplace:
	var workplace := Workplace.new()
	workplace.spot_name = name_of_spot
	workplace.spot_tile = tile
	return workplace


## What it is called: the building's name, or the spot's.
func label() -> String:
	return building.type_data()["name"] if building != null else spot_name


## Where they stand to work, in tiles of the world: the yard in front of a building's door, or the
## middle of the spot's tile.
func spot() -> Vector2:
	return building.yard() if building != null else Vector2(spot_tile) + Vector2(0.5, 0.5)


func to_dict() -> Dictionary:
	if building != null:
		return {"building": SaveCodec.vector_to_json(building.origin)}
	return {"spot_name": spot_name, "spot_tile": SaveCodec.vector_to_json(spot_tile)}


## The workplace saved in `data`; the buildings are those of `world`, which the save validator
## has seen to stand.
static func from_dict(data: Dictionary, world: World) -> Workplace:
	if data.has("building"):
		return of_building(world.building_at(SaveCodec.vector_from_json(data["building"])))
	return of_spot(data["spot_name"], SaveCodec.vector_from_json(data["spot_tile"]))
