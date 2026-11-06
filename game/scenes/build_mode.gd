class_name BuildMode
extends Node2D
## Placing a building. While the player holds the hammer (see Builder) a ghost of the chosen
## building follows the mouse, snapped to tiles: green where it can be built, with the blocked
## tiles marked red. A click or Use places it, Q and E pick the building, a right click
## dismisses build mode. The land's rules are World's, the materials' Builder's.
##
## X switches to taking down: the building or placed thing under the mouse is marked red, the
## message says what taking it down gives, and holding Use for a second does it.
##
## Debug flags (see StartupOptions): `--ghost` pins the ghost's top left tile; `--house` places
## the chosen building as soon as its chunks are loaded.

## The message to show, or "" to hide it. It is drawn by the UI, outside the world viewport.
signal message_changed(text: String)
## A click or Use tried to place the building and could not.
signal placement_refused
## A building or a placed thing was taken down; `tile` is one of its tiles.
signal taken_down(tile: Vector2i)

const UNSAFE_LAND_MESSAGE := "This land doesn't look safe to build on."
const OCCUPIED_MESSAGE := "Something is in the way."
const MISSING_MESSAGE := "You lack the materials."
const TAKING_DOWN_MESSAGE := "Taking down. Point at a building or something you placed."
## How long the use button is held to take something down.
const TAKE_DOWN_SECONDS := 1.0

# Palette colours (see tools/art/palette.py).
const VALID_TINT := Color("82a352", 0.5)
const BLOCKED_TINT := Color("a8402e", 0.7)
const GHOST_MODULATE := Color(1, 1, 1, 0.7)
const TAKE_DOWN_TINT := Color("a8402e", 0.55)
const TAKE_DOWN_OUTLINE := Color("a8402e")
const PROGRESS_BACKGROUND := Color(0, 0, 0, 0.6)
const PROGRESS_COLOR := Color("dc7a37")
const PROGRESS_HEIGHT := 4.0

var world: World
var builder: Builder
## Turns the mouse position into a world position.
var camera: CameraController
## The `--ghost` and `--house` flags.
var start_options := StartupOptions.new()

var _origin := Vector2i.ZERO
var _blockers: Dictionary[Vector2i, World.Blocked] = {}
var _is_snowy := false
var _texture: Texture2D
var _was_active := false
var _is_debug_house_placed := false
var _take_down_target: TakeDownTarget
## How long the use button has been held on the target, in seconds.
var _held_seconds := 0.0
var _cursor_tile := Vector2i.ZERO
## Why the target stays, or "" (see `_show_take_down_message`).
var _take_down_reason := ""


## Shows the ghost with snow on its roof, as a house looks while there is snow about.
func set_snowy(is_snowy: bool) -> void:
	_is_snowy = is_snowy


func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	if builder.is_taking_down():
		if not _handle_take_down_input(event):
			return
	elif event.is_action_pressed("take_down_mode"):
		_toggle_taking_down()
	elif event.is_action_pressed("build_previous"):
		builder.pick(-1)
	elif event.is_action_pressed("build_next"):
		builder.pick(1)
	elif event.is_action_pressed("use") or event.is_action_pressed("use_click"):
		_place()
	elif _is_right_click(event):
		_dismiss()
	else:
		return
	get_viewport().set_input_as_handled()


## Returns whether the event was taken. Taking down is held, not pressed (see
## `_hold_to_take_down`), but a press of Use must not reach the game as a use either.
func _handle_take_down_input(event: InputEvent) -> bool:
	if event.is_action_pressed("take_down_mode"):
		_toggle_taking_down()
	elif _is_right_click(event):
		_dismiss()
	else:
		return event.is_action_pressed("use") or event.is_action_pressed("use_click")
	return true


func _toggle_taking_down() -> void:
	builder.toggle_taking_down()
	_take_down_target = null
	_held_seconds = 0.0


func _is_right_click(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	)


func _dismiss() -> void:
	builder.dismiss()
	message_changed.emit("")


func _process(delta: float) -> void:
	if world == null:
		return
	var house := start_options.house
	if (
		not _is_debug_house_placed
		and house != StartupOptions.NO_TILE
		and _is_footprint_loaded(house)
	):
		if world.place_building(builder.choice, house) == null:
			push_error("--house: can't place a house at %s" % house)
		_is_debug_house_placed = true
	var is_now_active := is_active()
	if is_now_active != _was_active:
		_was_active = is_now_active
		queue_redraw()
		if not is_now_active:
			message_changed.emit("")
	if not is_now_active:
		return
	if builder.is_taking_down():
		_hold_to_take_down(delta)
		queue_redraw()
		return
	_origin = start_options.ghost
	if _origin == StartupOptions.NO_TILE:
		_origin = _origin_under(camera.mouse_world_position())
	_texture = load(
		SeasonalArt.house_path(
			BuildingTypes.TYPES[builder.choice]["sprite"],
			SeasonBlend.Look.SNOW if _is_snowy else SeasonBlend.Look.SUMMER
		)
	)
	_blockers = world.placement_blockers(builder.choice, _origin)
	_show_message()
	queue_redraw()


func _draw() -> void:
	if builder != null and builder.is_taking_down():
		_draw_take_down_target()
		return
	# The first frame can draw before _process has loaded the ghost's picture.
	if not is_active() or _texture == null:
		return
	var tile_size := TerrainTileset.TILE_SIZE
	var texture := _texture
	var top_left := Vector2(_origin * tile_size)
	var footprint_size := Vector2(_footprint() * tile_size)
	draw_texture(
		texture, top_left + Vector2(0, footprint_size.y - texture.get_height()), GHOST_MODULATE
	)
	var is_missing := not builder.shortfalls().is_empty()
	var footprint := Building.footprint_tiles(builder.choice, _origin)
	for pos in footprint:
		var tint := BLOCKED_TINT if is_missing or _blockers.has(pos) else VALID_TINT
		draw_rect(Rect2(Vector2(pos * tile_size), Vector2(tile_size, tile_size)), tint)
	# A blocked tile in front of the door is outside the footprint.
	for pos in _blockers:
		if pos not in footprint:
			draw_rect(Rect2(Vector2(pos * tile_size), Vector2(tile_size, tile_size)), BLOCKED_TINT)


## Whether the ghost is up: the player holds the hammer, and build mode is on screen (not
## inside, no console or screen over it).
func is_active() -> bool:
	return visible and builder != null and builder.is_building()


## Marks what the hammer points at and takes it down once Use has been held on it long enough.
func _hold_to_take_down(delta: float) -> void:
	var tile := start_options.ghost
	if tile == StartupOptions.NO_TILE:
		tile = Vector2i((camera.mouse_world_position() / TerrainTileset.TILE_SIZE).floor())
	_cursor_tile = tile
	var target := builder.take_down_target(tile)
	var is_same := (
		target != null and _take_down_target != null and target.is_same_as(_take_down_target)
	)
	if not is_same:
		_take_down_target = target
		_show_take_down_message()
	var is_using := Input.is_action_pressed("use") or Input.is_action_pressed("use_click")
	_held_seconds = (
		_held_seconds + delta if is_same and is_using and _take_down_reason == "" else 0.0
	)
	if _held_seconds >= TAKE_DOWN_SECONDS:
		var tile_taken := target.tiles()[0]
		# Builder checks the reason again, so a message one frame behind can't take down a house
		# that is not to go.
		if builder.take_down(target):
			taken_down.emit(tile_taken)
		_take_down_target = null
		_held_seconds = 0.0


## Says what the target gives or why it stays. Only when the target changes: the reason for a
## house reads its interior.
func _show_take_down_message() -> void:
	if _take_down_target == null:
		_take_down_reason = ""
		message_changed.emit(TAKING_DOWN_MESSAGE)
		return
	_take_down_reason = builder.why_not_take_down(_take_down_target)
	if _take_down_reason != "":
		message_changed.emit(_take_down_reason)
		return
	var gives := builder.take_down_gives(_take_down_target)
	message_changed.emit(
		"Take down %s: %s. Hold Use." % [_take_down_target.display_name(), _items_text(gives)]
	)


func _draw_take_down_target() -> void:
	var tile_size := TerrainTileset.TILE_SIZE
	# The cursor: a red frame round the tile the mouse is on, as the ghost is the cursor of building.
	draw_rect(
		Rect2(Vector2(_cursor_tile * tile_size), Vector2(tile_size, tile_size)),
		TAKE_DOWN_OUTLINE,
		false,
		1.0
	)
	if _take_down_target == null:
		return
	var covered := Rect2()
	for pos in _take_down_target.tiles():
		var tile_rect := Rect2(Vector2(pos * tile_size), Vector2(tile_size, tile_size))
		draw_rect(tile_rect, TAKE_DOWN_TINT)
		covered = tile_rect if covered.size == Vector2.ZERO else covered.merge(tile_rect)
	draw_rect(covered, TAKE_DOWN_OUTLINE, false, 1.0)
	if _held_seconds > 0.0:
		var bar := Rect2(
			covered.position - Vector2(0, PROGRESS_HEIGHT + 2),
			Vector2(covered.size.x, PROGRESS_HEIGHT)
		)
		draw_rect(bar, PROGRESS_BACKGROUND)
		bar.size.x *= minf(_held_seconds / TAKE_DOWN_SECONDS, 1.0)
		draw_rect(bar, PROGRESS_COLOR)


## "20 Logs, 5 Stone" for item id to count.
func _items_text(items: Dictionary) -> String:
	var parts: Array[String] = []
	for item: StringName in items:
		parts.append("%d %s" % [items[item], ItemTypes.TYPES[item]["name"]])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


func _place() -> void:
	# Builder checks the rules again, so a ghost one frame behind can't place a blocked house.
	if builder.place(_origin) == null:
		placement_refused.emit()


func _footprint() -> Vector2i:
	return BuildingTypes.TYPES[builder.choice]["footprint"]


## The footprint's top left tile when the cursor is on its middle.
func _origin_under(world_position: Vector2) -> Vector2i:
	var tile := Vector2i((world_position / TerrainTileset.TILE_SIZE).floor())
	return tile - _footprint() / 2


func _show_message() -> void:
	if not _blockers.is_empty():
		var is_unsafe_land := _blockers.values().has(World.Blocked.TERRAIN)
		message_changed.emit(UNSAFE_LAND_MESSAGE if is_unsafe_land else OCCUPIED_MESSAGE)
	elif not builder.shortfalls().is_empty():
		message_changed.emit(MISSING_MESSAGE)
	else:
		message_changed.emit("")


func _is_footprint_loaded(origin: Vector2i) -> bool:
	return Building.footprint_tiles(builder.choice, origin).all(
		func(pos: Vector2i) -> bool: return world.is_chunk_loaded(Chunk.world_to_chunk(pos))
	)
