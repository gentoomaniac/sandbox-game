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
	# Left as parsed: JSON numbers are floats, so the typed accessors convert.
	object.state = data["state"].duplicate()
	return object


## The tiles the object covers: its own and, for a bigger one, those to the right and down.
func tiles() -> Array[Vector2i]:
	var footprint: Vector2i = type_data()["footprint"]
	var covered: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			covered.append(pos + Vector2i(x, y))
	return covered


func covers(world_pos: Vector2i) -> bool:
	var offset := world_pos - pos
	var footprint: Vector2i = type_data()["footprint"]
	return offset.x >= 0 and offset.y >= 0 and offset.x < footprint.x and offset.y < footprint.y


func blocks_walking() -> bool:
	return type_data()["blocks_walking"]


## How long sleeping here takes, in game minutes. 0 if this is not a bed.
func sleep_minutes() -> int:
	return type_data().get("sleep_minutes", 0)


func is_crop() -> bool:
	return type_data().has("growth_stages")


## The whole days this crop, or stump or sapling that grows back, has grown.
func days_grown() -> int:
	return int(state.get("days_grown", 0))


func grow_one_day() -> void:
	assert(is_crop(), "Not a crop: %s" % type)
	state["days_grown"] = days_grown() + 1


## Crops only: the growth stage, 0 for a freshly planted one, up to `growth_stages - 1`.
func growth_stage() -> int:
	assert(is_crop(), "Not a crop: %s" % type)
	var crop_type: Dictionary = type_data()
	return mini(
		days_grown() / int(crop_type["days_per_stage"]), int(crop_type["growth_stages"]) - 1
	)


func is_ripe() -> bool:
	return is_crop() and growth_stage() == type_data()["growth_stages"] - 1


## The light this object shines (see WorldObjectTypes), or an empty dictionary.
func light() -> Dictionary:
	return type_data().get("light", {})


## The type's data (see WorldObjectTypes).
func type_data() -> Dictionary:
	return WorldObjectTypes.TYPES[type]


## Whether a hit of this power takes off its last hit points. They heal overnight, if it is
## not finished by then.
func is_finished_by(power: int) -> bool:
	return _damage() + power >= type_data()["hp"]


func take_hit(power: int) -> void:
	state["damage"] = _damage() + power


## Whether a hand can pick something off it right now: it has drops and no hit points.
func is_forageable() -> bool:
	return type_data().has("drops") and not type_data().has("hp") and not is_picked()


## Berry bushes and the like: picked, they bear again after a few days.
func is_picked() -> bool:
	return state.has("days_until_bears")


func pick() -> void:
	state["days_until_bears"] = type_data()["regrow_days"]


## A stump or sapling that grows back into a tree remembers which one in `state["tree"]`.
func _is_growing_back() -> bool:
	return state.has("tree")


func is_mature() -> bool:
	return _is_growing_back() and days_grown() >= type_data()["matures_after_days"]


## What this one turns into when it matures: the next stage of the tree it grows back into.
func matured() -> WorldObject:
	var stage: Variant = type_data().get("matures_into")
	if stage == null:
		return WorldObject.new(StringName(state["tree"]), pos)
	var next := WorldObject.new(stage, pos)
	next.state["tree"] = state["tree"]
	return next


## Lets one night pass: damage heals, a crop grows, a picked bush bears again soon, something
## that grows back ages. Returns whether its look changed.
func pass_night() -> bool:
	state.erase("damage")
	if is_crop():
		grow_one_day()
		return true
	if is_picked():
		var days_left := int(state["days_until_bears"]) - 1
		if days_left > 0:
			state["days_until_bears"] = days_left
		else:
			state.erase("days_until_bears")
		return days_left <= 0
	if _is_growing_back():
		state["days_grown"] = days_grown() + 1
	return false


## Hit points already taken off.
func _damage() -> int:
	return int(state.get("damage", 0))
