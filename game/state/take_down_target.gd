class_name TakeDownTarget
extends RefCounted
## What the hammer in take-down mode would take down on a tile: a building, or a thing the
## player placed outdoors (a chest, a workbench). Exactly one of `building` and `object` is set.

var building: Building
var object: WorldObject


static func of_building(target: Building) -> TakeDownTarget:
	var found := TakeDownTarget.new()
	found.building = target
	return found


static func of_object(target: WorldObject) -> TakeDownTarget:
	var found := TakeDownTarget.new()
	found.object = target
	return found


func display_name() -> String:
	if building != null:
		return building.type_data()["name"]
	return ItemTypes.TYPES[ItemTypes.item_placing(object.type)]["name"]


## The tiles it covers.
func tiles() -> Array[Vector2i]:
	return building.tiles() if building != null else object.tiles()


func is_same_as(other: TakeDownTarget) -> bool:
	return building == other.building and object == other.object
