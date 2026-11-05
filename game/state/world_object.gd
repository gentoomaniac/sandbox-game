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


func blocks_walking() -> bool:
	return WorldObjectTypes.TYPES[type]["blocks_walking"]
