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
	CropLife.upgrade_old_state(object)
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


## The whole days a stump or sapling that grows back has grown.
func days_grown() -> int:
	return int(state.get("days_grown", 0))


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


## Whether a hand can pick something off it right now: it has drops and no hit points, and
## needs no tool (tall grass is mown).
func is_forageable() -> bool:
	var object_type := type_data()
	return (
		object_type.has("drops")
		and not object_type.has("hp")
		and not object_type.has("tool")
		and not is_picked()
	)


## Whether a scythe can mow it now: it is something that gets mown and is not mown already.
func is_mowable() -> bool:
	return type_data().get("tool") == &"scythe" and not is_picked()


## Berry bushes and the like: picked (or mown, for tall grass), they bear again after a few days.
func is_picked() -> bool:
	return state.has("days_until_bears")


func pick() -> void:
	state["days_until_bears"] = type_data()["regrow_days"]


## A stump or sapling of a tree that can grow remembers which one in `state["tree"]`.
func _is_of_a_tree() -> bool:
	return state.has("tree")


## Whether a sapling has grown up. One without a tree in its state (a wild one) never does.
func is_mature() -> bool:
	return (
		_is_of_a_tree()
		and type_data().has("matures_after_days")
		and days_grown() >= type_data()["matures_after_days"]
	)


## The tree this sapling grows into.
func matured() -> WorldObject:
	return WorldObject.new(StringName(state["tree"]), pos)


## Whether a stump has rotted away.
func has_rotted() -> bool:
	return type_data().has("rots_after_days") and days_grown() >= type_data()["rots_after_days"]


## What a rotted stump leaves: a sapling of its tree with the type's chance (the same stump on
## the same day always rolls the same), or null, nothing.
func rotted(day: int) -> WorldObject:
	var chance: float = type_data()["rots_into_sapling_chance"]
	if not _is_of_a_tree() or PositionHash.of(pos, day) % 100 >= chance * 100:
		return null
	var sapling := WorldObject.new(WorldObjectTypes.SAPLING, pos)
	sapling.state["tree"] = state["tree"]
	return sapling


## What a hand picks off it, item id to count. A sapling of a tree gives that tree's seed.
func picked_drops() -> Dictionary:
	if type == WorldObjectTypes.SAPLING and _is_of_a_tree():
		return {WorldObjectTypes.TYPES[StringName(state["tree"])]["seed"]: 1}
	return type_data()["drops"]


## Lets one night pass: damage heals, a picked bush bears again soon, something that grows back
## ages. Returns whether its look changed. A crop lives through the day's weather instead (see
## CropLife).
func pass_night() -> bool:
	state.erase("damage")
	if is_crop():
		return false
	if is_picked():
		var days_left := int(state["days_until_bears"]) - 1
		if days_left > 0:
			state["days_until_bears"] = days_left
		else:
			state.erase("days_until_bears")
		return days_left <= 0
	# A sapling of a tree grows up, a stump rots: both just count their days.
	if _is_of_a_tree() or type_data().has("rots_after_days"):
		state["days_grown"] = days_grown() + 1
	return false


## Hit points already taken off.
func _damage() -> int:
	return int(state.get("damage", 0))
