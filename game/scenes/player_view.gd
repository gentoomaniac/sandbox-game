class_name PlayerView
extends Node2D
## Draws the PlayerState: one sprite per worn layer (see Appearance), all showing the same
## frame at the player's position. Walking comes from how the position changed since the
## last frame.
##
## Debug: `--hair=<n>` wears variant "n" of the hair (F6 cycles 0 and 1; what the
## character wears comes from the equipment, see `--wear` in Main);
## `--pose=<up|down|left|right>[,<column>]` turns the player and optionally freezes the
## animation on a column of the sheet (0 idle, 1 to 4 the walk frames).

## A foot came down: time for a footstep sound.
signal stepped

## Frames per facing in every layer sheet: idle, walk 1 to 4.
const FRAMES_PER_FACING := 5
## Sheet rows by facing, in the order the art generator draws them.
const FACING_ROWS := {Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3}
## Sheets are 16x32 frames: one tile wide, two tall.
const FRAME_HEIGHT := 32
const IDLE_COLUMN := 0
## A walk cycle visits these columns, step after step.
const WALK_COLUMNS := [1, 2, 3, 4]
const WALK_FRAMES_PER_SECOND := 10.0
## The walk frames where a foot comes down, two per cycle.
const STEP_COLUMNS := [1, 3]
## The hair variants that `--hair` and F6 cycle through.
const HAIR_COUNT := 2
const HAIR_KEY := KEY_F6
const FACINGS_BY_NAME := {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT
}

## How fast the player walks (see GameState `walk_speed_factor`); the walk animation, and so the
## steps, keep that pace.
var walk_speed := 1.0

var _player: PlayerState
var _last_column := IDLE_COLUMN
var _last_position := Vector2.ZERO
var _walk_time := 0.0
var _hair := 0
var _frozen_column := -1
## The sheets the sprites show now, bottom first. The sprites are rebuilt when they change.
var _shown_sheets: Array[String] = []
var _sprites: Array[Sprite2D] = []


## The sheet column of a frame: idle when standing, else a step of the walk cycle.
static func frame_column(walking: bool, walk_time: float) -> int:
	if not walking:
		return IDLE_COLUMN
	return WALK_COLUMNS[int(walk_time * WALK_FRAMES_PER_SECOND) % WALK_COLUMNS.size()]


## The frame number in a layer sheet (the sheets all have the same layout).
static func frame_index(facing: Vector2i, column: int) -> int:
	return FACING_ROWS[facing] * FRAMES_PER_FACING + column


func show_player(player: PlayerState) -> void:
	_player = player
	_last_position = player.position
	position = (player.position * TerrainTileset.TILE_SIZE).round()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hair="):
			_wear_hair(int(arg.trim_prefix("--hair=")))
		elif arg.begins_with("--pose="):
			var parts := arg.trim_prefix("--pose=").split(",")
			player.facing = FACINGS_BY_NAME[parts[0]]
			if parts.size() > 1:
				_frozen_column = int(parts[1])


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == HAIR_KEY:
		_wear_hair((_hair + 1) % HAIR_COUNT)


func _process(delta: float) -> void:
	if _player == null:
		return
	var moved := _player.position - _last_position
	_last_position = _player.position
	position = (_player.position * TerrainTileset.TILE_SIZE).round()
	if moved != Vector2.ZERO:
		_walk_time += delta * walk_speed
	else:
		_walk_time = 0.0
	var column := frame_column(moved != Vector2.ZERO, _walk_time)
	if _frozen_column >= 0:
		column = _frozen_column
	if column != _last_column and column in STEP_COLUMNS:
		stepped.emit()
	_last_column = column
	_show_held_item()
	_show_layers(_player.appearance.layers_for(_player.facing))
	for sprite in _sprites:
		sprite.frame = frame_index(_player.facing, column)


## The hand shows the selected item, if it has art for the hand (the hoe); else it is empty.
func _show_held_item() -> void:
	var held: StringName = _player.inventory.held_item()
	var held_sheet: Variant = ItemTypes.TYPES.get(held, {}).get("held_sheet")
	if held_sheet == null:
		_player.appearance.take_off(Appearance.HELD)
	else:
		_player.appearance.wear(Appearance.HELD, held_sheet)


func _wear_hair(hair: int) -> void:
	_hair = hair
	_player.appearance.wear(Appearance.HAIR, str(hair))


func _show_layers(layers: Array[Dictionary]) -> void:
	var sheets: Array[String] = []
	for layer in layers:
		sheets.append(Appearance.sheet_path(layer))
	if sheets == _shown_sheets:
		return
	_shown_sheets = sheets
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	for sheet in sheets:
		var sprite := Sprite2D.new()
		sprite.texture = load(sheet)
		sprite.hframes = FRAMES_PER_FACING
		sprite.vframes = FACING_ROWS.size()
		# The frame's bottom centre is at the feet.
		sprite.offset = Vector2(0, -FRAME_HEIGHT / 2.0)
		add_child(sprite)
		_sprites.append(sprite)
