class_name FriendshipPopups
extends Node2D
## The pop-up over a villager's head when their opinion of the player moves: a heart when it
## rises, a grey cloud when it falls (tools/art/friendship.py, in both art sets). It rises a little
## and fades; the heart beats and the cloud drizzles as it goes, two pictures taking turns.

const HEART_PATH := "res://assets/effects/friendship_heart.png"
const CLOUD_PATH := "res://assets/effects/friendship_cloud.png"
## The two pictures of each are side by side in one file.
const FRAMES := 2
const FRAME_SECONDS := 0.35
## How long a pop-up lasts, in seconds, and how far it rises, in art pixels.
const POP_SECONDS := 1.4
const RISE := 14.0
## How far above the villager's feet the bottom of the pop-up starts, in art pixels: just over the
## head of a figure 61 px tall.
const HEAD_HEIGHT := 64.0

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
	var mark := Sprite2D.new()
	mark.texture = load(ArtSet.path(HEART_PATH if is_gain else CLOUD_PATH))
	mark.hframes = FRAMES
	mark.offset.y = -mark.texture.get_height() / 2.0
	mark.position = npc.position * TerrainTileset.TILE_SIZE - Vector2(0, HEAD_HEIGHT)
	add_child(mark)
	var tween := mark.create_tween()
	tween.set_parallel()
	tween.tween_property(mark, "position:y", mark.position.y - RISE, POP_SECONDS)
	tween.tween_property(mark, "modulate:a", 0.0, POP_SECONDS)
	# The pictures take turns, one every FRAME_SECONDS.
	tween.tween_method(
		func(turns: float) -> void: mark.frame = int(turns) % FRAMES,
		0.0,
		POP_SECONDS / FRAME_SECONDS,
		POP_SECONDS
	)
	tween.chain().tween_callback(mark.queue_free)
