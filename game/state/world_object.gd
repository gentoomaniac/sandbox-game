class_name WorldObject
extends RefCounted
## One thing standing on a tile: a tree, a rock, later crops and buildings. Its kind is
## data in WorldObjectTypes; what is specific to this one (hits left, growth stage...) lives
## in `state`.

var type: StringName
## World tile position.
var pos: Vector2i
var state := {}


func _init(object_type: StringName, world_pos: Vector2i) -> void:
	assert(WorldObjectTypes.TYPES.has(object_type), "Unknown object type: %s" % object_type)
	type = object_type
	pos = world_pos


func to_dict() -> Dictionary:
	return {"type": str(type), "pos": SaveCodec.vector_to_json(pos), "state": state.duplicate()}


static func from_dict(data: Dictionary) -> WorldObject:
	var object := WorldObject.new(StringName(data["type"]), SaveCodec.vector_from_json(data["pos"]))
	# JSON has only floats; the whole numbers in the state (days_grown) must be ints again.
	for key: String in data["state"]:
		var value: Variant = data["state"][key]
		object.state[key] = int(value) if value is float and value == floorf(value) else value
	return object


func blocks_walking() -> bool:
	return WorldObjectTypes.TYPES[type]["blocks_walking"]


## How long sleeping here takes, in game minutes. 0 if this is not a bed.
func sleep_minutes() -> int:
	return WorldObjectTypes.TYPES[type].get("sleep_minutes", 0)


func is_crop() -> bool:
	return WorldObjectTypes.TYPES[type].has("growth_stages")


## Crops only: the whole days this crop has grown.
func days_grown() -> int:
	return state.get("days_grown", 0)


func grow_one_day() -> void:
	assert(is_crop(), "Not a crop: %s" % type)
	state["days_grown"] = days_grown() + 1


## Crops only: the growth stage, 0 for a freshly planted one, up to `growth_stages - 1`.
func growth_stage() -> int:
	assert(is_crop(), "Not a crop: %s" % type)
	var crop_type: Dictionary = WorldObjectTypes.TYPES[type]
	return mini(
		days_grown() / int(crop_type["days_per_stage"]), int(crop_type["growth_stages"]) - 1
	)


func is_ripe() -> bool:
	return is_crop() and growth_stage() == WorldObjectTypes.TYPES[type]["growth_stages"] - 1


## The light this object shines (see WorldObjectTypes), or an empty dictionary.
func light() -> Dictionary:
	return WorldObjectTypes.TYPES[type].get("light", {})
