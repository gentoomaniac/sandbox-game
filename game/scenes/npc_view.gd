class_name NpcView
extends Node2D
## A villager (Npc) in the world, or in the room they are in: one sprite per layer of its look,
## drawn like the player (see PlayerView, whose sheets and frames it shares) on a contact shadow,
## walking while it moves. It lives among the y-sorted entities of the world view or of the room,
## so it stands behind and in front of things as the player does.

## The walk frames go at this fraction of the player's pace: villagers stroll.
const WALK_PACE := 0.5

var npc: Npc
## Whether it is drawn in the room the villager is inside: at `Npc.inside_position`, not `position`.
var _is_in_room: bool
var _sprites: Array[Sprite2D] = []
var _last_position: Vector2
var _walk_time := 0.0


func _init(shown_npc: Npc, is_in_room := false) -> void:
	npc = shown_npc
	_is_in_room = is_in_room
	_last_position = _feet()
	position = _pixel_position()
	add_to_group(ArtSet.VIEWS)
	for layer in npc.appearance.layers:
		var sprite := Sprite2D.new()
		sprite.hframes = PlayerView.FRAMES_PER_FACING
		sprite.vframes = PlayerView.FACING_ROWS.size()
		# The frame's bottom centre is at the feet.
		sprite.offset = Vector2(0, -PlayerView.FRAME_HEIGHT / 2.0)
		add_child(sprite)
		_sprites.append(sprite)
	show_art_set()
	_show_frame(0.0)


## Loads the layers' sheets in the chosen art set.
func show_art_set() -> void:
	for index in _sprites.size():
		var sheet := Appearance.sheet_path(npc.appearance.layers[index])
		_sprites[index].texture = load(ArtSet.path(sheet))


func _process(delta: float) -> void:
	_show_frame(delta)


func _draw() -> void:
	Animal.draw_contact_shadow(self, PlayerView.FIGURE_SHADOW_HALF_WIDTH)


func _show_frame(delta: float) -> void:
	var is_walking := _feet() != _last_position
	_last_position = _feet()
	position = _pixel_position()
	_walk_time = _walk_time + delta * WALK_PACE if is_walking else 0.0
	var frame := PlayerView.frame_index(npc.facing, PlayerView.frame_column(is_walking, _walk_time))
	for sprite in _sprites:
		sprite.frame = frame


## Rounded to whole art pixels, so the villager stays put on the world as the camera moves.
func _pixel_position() -> Vector2:
	return (_feet() * TerrainTileset.TILE_SIZE).round()


func _feet() -> Vector2:
	return npc.inside_position if _is_in_room else npc.position
