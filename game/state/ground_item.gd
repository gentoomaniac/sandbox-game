class_name GroundItem
extends RefCounted
## A pile of one kind of item lying on the ground of the world. It blocks nothing; the player
## collects it by walking over it (see GameState `collect_ground_items`).

var item: StringName
var count: int
## World position, in tiles: sub-tile, so piles on one tile don't lie on top of each other.
var position: Vector2
## Seconds before a freshly dropped pile can be pulled to the player: it hops out first (see
## GroundItemView; a felled tree's seed waits for the tree to land). Not saved: a loaded pile
## lies still.
var settle_seconds := 0.0
## Set on what the player dropped from the inventory: it is not pulled back until the player has
## walked out of its reach, then it lies like any pile. Not saved.
var is_dropped_by_player := false


func _init(item_id: StringName, item_count: int, world_position: Vector2) -> void:
	item = item_id
	count = item_count
	position = world_position


static func from_dict(data: Dictionary) -> GroundItem:
	var item_id := StringName(data["item"])
	assert(ItemTypes.TYPES.has(item_id), "Unknown item in save: %s" % item_id)
	return GroundItem.new(
		item_id, int(data["count"]), SaveCodec.float_vector_from_json(data["position"])
	)
