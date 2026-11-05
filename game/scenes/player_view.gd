class_name PlayerView
extends Node2D
## Draws the PlayerState: the right frame of the character at their position. Walking comes
## from how the position changed since the last frame.

const ATLAS_PATH := "res://assets/player.png"
## Frames per facing in assets/player.png: idle, walk 1, walk 2.
const FRAMES_PER_FACING := 3
## Atlas rows by facing, in the order the art generator draws them.
const FACING_ROWS := {Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3}
const IDLE_COLUMN := 0
## A walk cycle visits these columns, step after step.
const WALK_COLUMNS := [1, 0, 2, 0]
const WALK_FRAMES_PER_SECOND := 8.0

var _player: PlayerState
var _last_position := Vector2.ZERO
var _walk_time := 0.0
var _sprite := Sprite2D.new()


func _ready() -> void:
	_sprite.texture = load(ATLAS_PATH)
	_sprite.hframes = FRAMES_PER_FACING
	_sprite.vframes = FACING_ROWS.size()
	# The cell's bottom centre is at the feet.
	_sprite.offset = Vector2(0, -TerrainTileset.TILE_SIZE / 2.0)
	add_child(_sprite)


func show_player(player: PlayerState) -> void:
	_player = player
	_last_position = player.position
	position = (player.position * TerrainTileset.TILE_SIZE).round()


func _process(delta: float) -> void:
	if _player == null:
		return
	var moved := _player.position - _last_position
	_last_position = _player.position
	position = (_player.position * TerrainTileset.TILE_SIZE).round()
	var column := IDLE_COLUMN
	if moved != Vector2.ZERO:
		_walk_time += delta
		column = WALK_COLUMNS[int(_walk_time * WALK_FRAMES_PER_SECOND) % WALK_COLUMNS.size()]
	else:
		_walk_time = 0.0
	_sprite.frame = FACING_ROWS[_player.facing] * FRAMES_PER_FACING + column
