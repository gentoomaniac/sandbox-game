class_name QuestMarkView
extends Node2D
## The "!" over each notice board while a quest is posted that the player has not taken yet (see
## BoardNotices `has_news`): a small mark that bobs, two pictures of it taking turns. The boards are
## those of the world, the village's and the ones the player put up.

const MARK_PATH := "res://assets/effects/quest_mark.png"
## The two pictures of the mark are side by side in one file.
const FRAMES := 2
const FRAME_SECONDS := 0.6
## How often the boards and the news are looked at again, in seconds.
const LOOK_SECONDS := 0.5
## How tall the picture of the board is, in art pixels (the same in both art sets), and how far
## above it the mark hangs.
const BOARD_HEIGHT := 56
const GAP := 3

var _state: GameState
## The mark over each board, by the board's tile.
var _marks: Dictionary[Vector2i, Sprite2D] = {}
var _since_look := LOOK_SECONDS


func _init(state: GameState) -> void:
	_state = state
	# Above the objects it hangs over, whatever their depth.
	z_index = 1
	add_to_group(ArtSet.VIEWS)


func _process(delta: float) -> void:
	_since_look += delta
	if _since_look >= LOOK_SECONDS:
		_since_look = 0.0
		_look()
	var frame := int(Time.get_ticks_msec() / (FRAME_SECONDS * 1000.0)) % FRAMES
	for mark in _marks.values():
		mark.frame = frame


## The new art or the classic is shown: the marks get its picture.
func show_art_set() -> void:
	for mark in _marks.values():
		_dress(mark)


## Puts a mark over each board while there is news, and takes them away when there is none or the
## board is gone.
func _look() -> void:
	var tiles: Array[Vector2i] = []
	if BoardNotices.has_news(_state):
		for object in _state.world.edited_objects():
			if object.type == WorldObjectTypes.NOTICE_BOARD:
				tiles.append(object.pos)
	for tile in _marks.keys():
		if not tiles.has(tile):
			_marks[tile].queue_free()
			_marks.erase(tile)
	for tile in tiles:
		if not _marks.has(tile):
			var mark := Sprite2D.new()
			mark.hframes = FRAMES
			mark.position = Vector2(
				(tile.x + 0.5) * TerrainTileset.TILE_SIZE,
				(tile.y + 1) * TerrainTileset.TILE_SIZE - BOARD_HEIGHT - GAP
			)
			_dress(mark)
			add_child(mark)
			_marks[tile] = mark


## Gives the mark the picture of the art set shown, standing on its bottom edge.
func _dress(mark: Sprite2D) -> void:
	var texture: Texture2D = load(ArtSet.path(MARK_PATH))
	mark.texture = texture
	mark.offset = Vector2(0.0, -texture.get_height() / 2.0)
