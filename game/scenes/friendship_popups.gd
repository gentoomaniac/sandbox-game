class_name FriendshipPopups
extends Node2D
## The pop-up over a villager's head when their opinion of the player moves: a heart when it
## rises, a grey cloud when it falls. It rises a little and fades. PLACEHOLDER: plain shapes drawn
## in code in palette colours; the art of #48 step 14 (a pixel artist) is to replace them with
## drawn pictures, a heart and a cloud, in both art sets (see FriendshipMarks for the tab).

## How long a pop-up lasts, in seconds, and how far it rises, in art pixels.
const POP_SECONDS := 1.4
const RISE := 14.0
## How far above the villager's feet the pop-up starts, in art pixels (about their head).
const HEAD_HEIGHT := 44.0
## Palette colours (see tools/art/palette.py): the heart ember, the cloud stone_light with a
## stone_dark rim, and ink for the heart's rim.
const HEART_COLOR := Color("a8402e")
const CLOUD_COLOR := Color("a8a39c")
const RIM_COLOR := Color("4a4852")

var _state: GameState


func _init(state: GameState, notes: FriendshipNotes) -> void:
	_state = state
	# Above the villagers it hangs over, whatever their depth.
	z_index = 1
	notes.moved.connect(pop)


## Puts a heart (`is_gain`) or a cloud over the head of `npc`, if they are out in the world with the
## player: a villager indoors is not seen.
func pop(npc: Npc, is_gain: bool) -> void:
	if npc.inside != null or _state.is_inside():
		return
	var shape := Mark.new()
	shape.is_heart = is_gain
	shape.position = npc.position * TerrainTileset.TILE_SIZE - Vector2(0, HEAD_HEIGHT)
	add_child(shape)
	var tween := shape.create_tween()
	tween.set_parallel()
	tween.tween_property(shape, "position:y", shape.position.y - RISE, POP_SECONDS)
	tween.tween_property(shape, "modulate:a", 0.0, POP_SECONDS)
	tween.chain().tween_callback(shape.queue_free)


## One heart or cloud, drawn from its centre.
class Mark:
	extends Node2D

	var is_heart := true

	func _draw() -> void:
		if is_heart:
			draw_circle(Vector2(-3, -2), 3.5, RIM_COLOR)
			draw_circle(Vector2(3, -2), 3.5, RIM_COLOR)
			draw_colored_polygon(
				PackedVector2Array([Vector2(-6.5, -1), Vector2(6.5, -1), Vector2(0, 7)]), RIM_COLOR
			)
			draw_circle(Vector2(-3, -2), 2.5, HEART_COLOR)
			draw_circle(Vector2(3, -2), 2.5, HEART_COLOR)
			draw_colored_polygon(
				PackedVector2Array([Vector2(-5.5, -1), Vector2(5.5, -1), Vector2(0, 6)]),
				HEART_COLOR
			)
		else:
			for part in [Vector2(-4, 1), Vector2(4, 1), Vector2(0, -2)]:
				draw_circle(part, 4.5, RIM_COLOR)
			for part in [Vector2(-4, 1), Vector2(4, 1), Vector2(0, -2)]:
				draw_circle(part, 3.5, CLOUD_COLOR)
