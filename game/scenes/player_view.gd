class_name PlayerView
extends Node2D
## Draws the PlayerState: one sprite per worn layer (see Appearance), all showing the same
## frame at the player's position. Walking comes from how the position changed since the
## last frame.
##
## Debug: `--hair=<n>` wears variant "n" of the hair (F6 cycles 0 to 2; what the
## character wears comes from the equipment, see `--wear`);
## `--pose=<up|down|left|right>[,<column>]` turns the player and optionally freezes the
## animation on a column of the sheet (0 idle, 1 to 4 the walk frames). Both are in
## StartupOptions, which `show_player` reads.
##
## Passing out (`collapse`) shows the collapse sheets instead (see Appearance): the player sinks
## to the knees, tips over and lies asleep with rising "z"s, until `stand_up`. A player in a bed
## (PlayerState `bed_lying_in`) lies there in the same asleep frame, laid with its head to the
## head end of the bed.
##
## On horseback (PlayerState `horse`) the layers show their riding sheets on the ridden horse's
## sheets (see tools/art/livestock.py): the horse behind the rider, and what of it is in front of
## them (its head, coming towards the viewer). The horse stands, walks or trots, and the rider sits
## in its saddle and rises with the trot.

## A foot came down: time for a footstep sound.
signal stepped

## The sheets the layers show: standing and walking, passing out, or on horseback.
enum Pose { STANDING, COLLAPSE, RIDING }

## Frames per facing in every layer sheet: idle, walk 1 to 4.
const FRAMES_PER_FACING := 5
## Sheet rows by facing, in the order the art generator draws them.
const FACING_ROWS := {Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3}
## Sheets have frames one tile wide and two tall.
const FRAME_HEIGHT := 2 * TerrainTileset.TILE_SIZE
const IDLE_COLUMN := 0
## A walk cycle visits these columns, step after step.
const WALK_COLUMNS := [1, 2, 3, 4]
const WALK_FRAMES_PER_SECOND := 10.0
## The walk frames where a foot comes down, two per cycle.
const STEP_COLUMNS := [1, 3]
## The hair variants that `--hair` and F6 cycle through.
const HAIR_COUNT := 3
const HAIR_KEY := KEY_F6
const FACINGS_BY_NAME := {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT
}
## When each frame of a collapse sheet begins, in seconds after `collapse`: kneeling, tipping
## over, lying and asleep. The sheets face right and are mirrored for a player facing left;
## facing up or down, the player falls to the right.
const COLLAPSE_FRAME_STARTS := [0.0, 0.5, 0.65, 0.95]
const ASLEEP_FRAME := 3
## From standing to asleep, with a moment of the "z"s: Main fades out after this.
const COLLAPSE_SECONDS := 1.5
## How the asleep frame (head to the right, in the bottom half of the frame) is laid in a bed
## whose head end lies in this direction: how it is turned and moved, in art pixels, so that the
## figure's middle is on the player's position, the middle of the bed. In the box bed (head to
## the left) it lies a little left and up, measured on its picture, so that the head is on the
## pillow and the clogs stay under the blanket.
const LYING_POSES := {
	Vector2i.UP:
	{
		"rotation": -PI / 2,
		"shift": Vector2(16, 0),
		"is_flipped": false,
	},
	Vector2i.LEFT:
	{
		"rotation": 0.0,
		"shift": Vector2(-2, 14),
		"is_flipped": true,
	},
}
## A figure in a bed is drawn above the objects of the world (a sleeping bag lies among them);
## the cover of a bed in a house is drawn above the figure (see InteriorView).
const LYING_Z_INDEX := 1
## What is drawn over a figure in a bed (see InteriorView and ObjectCover).
const COVER_Z_INDEX := 2
## Where the "z"s start over a figure lying head to the right, in art pixels from the feet.
const SLEEP_ZS_POSITION := Vector2(12, -34)
## The ridden horse's sheets, behind the rider ("") and in front of them ("_over"), in the rows of
## FACING_ROWS: standing, four frames of the walk and four of the trot.
const RIDDEN_HORSE_PATH := "res://assets/wildlife/horse_%s_ridden%s.png"
const RIDE_COLUMNS := 9
const RIDE_IDLE_COLUMN := 0
const RIDE_WALK_COLUMNS := [1, 2, 3, 4]
const RIDE_TROT_COLUMNS := [5, 6, 7, 8]
## Frames of the walk per second; `walk_speed` makes the trot's faster.
const RIDE_FRAMES_PER_SECOND := 6.0
## Pixels the horse is off the ground in each column: the moments of the trot when no hoof is down.
## The rider rises with it.
const RIDE_LIFTS := [0, 0, 0, 0, 0, 0, 2, 0, 2]
## Where the rider's feet (the bottom centre of a riding frame) are on a horse facing right, in
## pixels from the horse's feet: the seat (row 46 of the riding frame) on the saddle's lowest row
## (row 20 of the horse's 76 px frame, row 31 of the pony's). Facing left it is mirrored, facing up
## or down it is in the middle.
const SEAT := Vector2(-3, -38)
const PONY_SEAT := Vector2(-2, -27)
## The same on the horses of the classic art (see ArtSet), the 16 px horse doubled.
const CLASSIC_SEAT := Vector2(-6, -22)
const CLASSIC_PONY_SEAT := Vector2(-4, -4)
## Half the width of the ridden horse's contact shadow seen from the front or from behind, from
## hoof to hoof (from the side it is that of FarmAnimalView), in pixels like the horse's art.
const RIDDEN_SHADOW_HALF_WIDTH := 8
## Half the width of the contact shadow under a figure on its feet, a player's or a villager's, in
## pixels (see Animal `draw_contact_shadow`): as wide as the clogs.
const FIGURE_SHADOW_HALF_WIDTH := 8

## How fast the player walks (see GameState `walk_speed_factor`); the walk animation, and so the
## steps, keep that pace.
var walk_speed := 1.0
## The horse the player rides trots (see GameState `is_trotting`).
var is_trotting := false
## The figure: the layers' sprites and what goes with them (the "z"s; Main adds the signs of
## tiredness). On horseback it sits in the saddle.
var figure := Node2D.new()

var _player: PlayerState
var _last_column := IDLE_COLUMN
var _last_position := Vector2.ZERO
var _walk_time := 0.0
var _hair := 0
var _frozen_column := -1
## Seconds since `collapse`, or -1 while the player is on their feet.
var _collapse_time := -1.0
var _sleep_zs := SleepZs.new()
var _horse_behind := Sprite2D.new()
var _horse_in_front := Sprite2D.new()
## The sheet the horse sprite behind the rider shows, in the chosen art set, to load the horse's
## sheets only when it changes.
var _shown_horse_sheet := ""
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


## The column of the ridden horse's sheets: standing, else a step of the walk or the trot.
static func ride_column(is_moving: bool, is_trotting_now: bool, walk_time: float) -> int:
	if not is_moving:
		return RIDE_IDLE_COLUMN
	var columns := RIDE_TROT_COLUMNS if is_trotting_now else RIDE_WALK_COLUMNS
	return columns[int(walk_time * RIDE_FRAMES_PER_SECOND) % columns.size()]


## The frame of the collapse sheets `time` seconds after the collapse began.
static func collapse_frame(time: float) -> int:
	var frame := 0
	for index in COLLAPSE_FRAME_STARTS.size():
		if time >= COLLAPSE_FRAME_STARTS[index]:
			frame = index
	return frame


func _init() -> void:
	for sprite in [_horse_behind, _horse_in_front]:
		sprite.offset = Vector2(0, -WildlifeSprites.HORSE["size"].y / 2.0)
		sprite.hframes = RIDE_COLUMNS
		sprite.vframes = FACING_ROWS.size()
		sprite.hide()
	add_child(_horse_behind)
	add_child(figure)
	add_child(_horse_in_front)
	figure.add_child(_sleep_zs)


func show_player(player: PlayerState, options := StartupOptions.new()) -> void:
	_player = player
	_last_position = player.position
	position = (player.position * TerrainTileset.TILE_SIZE).round()
	if options.hair >= 0:
		_wear_hair(options.hair)
	if options.pose != "":
		player.facing = FACINGS_BY_NAME[options.pose]
		_frozen_column = options.pose_column


## The player passes out where they stand (see the collapse sheets).
func collapse() -> void:
	_collapse_time = 0.0


## Back on their feet, as after waking up.
func stand_up() -> void:
	_collapse_time = -1.0
	_sleep_zs.is_sleeping = false


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
	_show_horse(_player.horse)
	# The contact shadow depends on riding, the collapse and the bed, so draw it anew every frame.
	queue_redraw()
	figure.position = Vector2.ZERO
	# Lying in a bed wins over riding (one who passes out with no room to get off stays in the
	# saddle), and riding over the collapse; all skip the walking frames below.
	var bed := _player.bed_lying_in
	z_index = LYING_Z_INDEX if bed != null else 0
	if bed != null:
		_show_lying_in_bed(bed)
		return
	if _player.horse != null:
		_show_riding(moved != Vector2.ZERO)
		return
	if _collapse_time >= 0.0:
		_show_collapse(delta)
		return
	var column := frame_column(moved != Vector2.ZERO, _walk_time)
	if _frozen_column >= 0:
		column = _frozen_column
	if column != _last_column and column in STEP_COLUMNS:
		stepped.emit()
	_last_column = column
	_show_held_item()
	_show_layers(_player.appearance.layers_for(_player.facing), Pose.STANDING)
	for sprite in _sprites:
		sprite.frame = frame_index(_player.facing, column)


## The contact shadow under the figure on its feet, or under the ridden horse and the rider. One
## who lies (passed out or in a bed) has none.
func _draw() -> void:
	if _player == null or _player.bed_lying_in != null:
		return
	if _player.horse == null:
		if _collapse_time < 0.0:
			Animal.draw_contact_shadow(self, FIGURE_SHADOW_HALF_WIDTH)
		return
	var half_width: int = (
		FarmAnimalView.SHADOW_HALF_WIDTHS[LivestockRules.HORSE]
		if _player.facing.x != 0
		else RIDDEN_SHADOW_HALF_WIDTH
	)
	Animal.draw_contact_shadow(self, half_width)


## Shows the horse the player rides, if any, in the horse sprites.
func _show_horse(horse: FarmAnimal) -> void:
	_horse_behind.visible = horse != null
	_horse_in_front.visible = horse != null
	if horse == null:
		_shown_horse_sheet = ""
		return
	# Set every frame, before the early return: two horses of one look share a sheet but not a tint.
	for sprite in [_horse_behind, _horse_in_front]:
		sprite.self_modulate = horse.tint
	var sheet := ArtSet.path(RIDDEN_HORSE_PATH % [horse.look, ""])
	if sheet == _shown_horse_sheet:
		return
	_shown_horse_sheet = sheet
	_horse_behind.texture = load(sheet)
	_horse_in_front.texture = load(ArtSet.path(RIDDEN_HORSE_PATH % [horse.look, "_over"]))


## The rider on the horse: its frame of standing, walking or trotting, and the figure in the
## saddle, rising with the trot. The hands hold the reins: no held item shows.
func _show_riding(is_moving: bool) -> void:
	var column := ride_column(is_moving, is_trotting, _walk_time)
	if _frozen_column >= 0:
		column = _frozen_column
	var row: int = FACING_ROWS[_player.facing]
	for sprite in [_horse_behind, _horse_in_front]:
		sprite.frame = row * RIDE_COLUMNS + column
	_show_layers(_layers_without_held_item(), Pose.RIDING)
	for sprite in _sprites:
		sprite.frame = row
	var is_pony := _player.horse.look == &"pony"
	var seat := PONY_SEAT if is_pony else SEAT
	if ArtSet.is_classic:
		seat = CLASSIC_PONY_SEAT if is_pony else CLASSIC_SEAT
	seat.x *= _player.facing.x
	figure.position = seat - Vector2(0, RIDE_LIFTS[column])


func _show_collapse(delta: float) -> void:
	_collapse_time += delta
	var frame := collapse_frame(_collapse_time)
	_show_layers(_layers_without_held_item(), Pose.COLLAPSE)
	var is_facing_left := _player.facing == Vector2i.LEFT
	for sprite in _sprites:
		_lay(sprite, frame, is_facing_left, 0.0, Vector2.ZERO)
	_sleep_zs.is_sleeping = frame == ASLEEP_FRAME
	_sleep_zs.position = SLEEP_ZS_POSITION * Vector2(-1 if is_facing_left else 1, 1)


func _show_lying_in_bed(bed: WorldObject) -> void:
	_show_layers(_layers_without_held_item(), Pose.COLLAPSE)
	var pose: Dictionary = LYING_POSES[bed.type_data()["bed"]]
	for sprite in _sprites:
		_lay(sprite, ASLEEP_FRAME, pose["is_flipped"], pose["rotation"], pose["shift"])
	_sleep_zs.is_sleeping = false


## The player's layers for the collapse and the riding sheets: the hand lets go of what it held.
func _layers_without_held_item() -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	for layer in _player.appearance.layers_for(Vector2i.RIGHT):
		if layer.slot != Appearance.HELD:
			layers.append(layer)
	return layers


## Shows a frame of a collapse sheet, mirrored, turned about its middle and moved.
func _lay(sprite: Sprite2D, frame: int, is_flipped: bool, angle: float, shift: Vector2) -> void:
	sprite.frame = frame
	sprite.flip_h = is_flipped
	sprite.rotation = angle
	sprite.position = shift


## The hand shows the selected item, if it has art for the hand (the tools); else it is empty.
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


## Shows the layers' sheets of a pose: standing, passing out or riding, in the chosen art set
## (a switch of the set changes the sheets, which rebuilds the sprites).
func _show_layers(layers: Array[Dictionary], pose: Pose) -> void:
	var sheets: Array[String] = []
	for layer in layers:
		match pose:
			Pose.STANDING:
				sheets.append(ArtSet.path(Appearance.sheet_path(layer)))
			Pose.COLLAPSE:
				sheets.append(ArtSet.path(Appearance.collapse_sheet_path(layer)))
			Pose.RIDING:
				sheets.append(ArtSet.path(Appearance.riding_sheet_path(layer)))
	if sheets == _shown_sheets:
		return
	_shown_sheets = sheets
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	# The "z"s and the signs of tiredness stay in front of the figure.
	var in_front := figure.get_children().filter(
		func(child: Node) -> bool: return not child.is_queued_for_deletion()
	)
	for sheet in sheets:
		var sprite := Sprite2D.new()
		sprite.texture = load(sheet)
		sprite.hframes = {
			Pose.STANDING: FRAMES_PER_FACING,
			Pose.COLLAPSE: COLLAPSE_FRAME_STARTS.size(),
			Pose.RIDING: 1,
		}[pose]
		sprite.vframes = 1 if pose == Pose.COLLAPSE else FACING_ROWS.size()
		# The frame's bottom centre is at the feet.
		sprite.offset = Vector2(0, -FRAME_HEIGHT / 2.0)
		figure.add_child(sprite)
		_sprites.append(sprite)
	for child: Node in in_front:
		figure.move_child(child, -1)
