class_name BuildMode
extends Node2D
## Placing a building. While the player holds the hammer (see Builder) a ghost of the chosen
## building follows the mouse, snapped to tiles: green where it can be built, with the blocked
## tiles marked red. A click or Use places it, Q and E pick the building, a right click
## dismisses build mode. The land's rules are World's, the materials' Builder's.
##
## Debug flags (see `make screenshot`): `--ghost=<x>,<y>` pins the ghost's top left tile
## there; `--house=<x>,<y>` places the chosen building there as soon as its chunks are loaded.

## The message to show, or "" to hide it. It is drawn by the UI, outside the world viewport.
signal message_changed(text: String)
## A click or Use tried to place the building and could not.
signal placement_refused

const UNSAFE_LAND_MESSAGE := "This land doesn't look safe to build on."
const OCCUPIED_MESSAGE := "Something is in the way."
const MISSING_MESSAGE := "You lack the materials."

# Palette colours (see tools/art/generate.py).
const VALID_TINT := Color("82a352", 0.5)
const BLOCKED_TINT := Color("a8402e", 0.7)
const GHOST_MODULATE := Color(1, 1, 1, 0.7)

var world: World
var builder: Builder
## Turns the mouse position into a world position.
var camera: CameraController

var _origin := Vector2i.ZERO
var _blockers: Dictionary[Vector2i, World.Blocked] = {}
var _is_snowy := false
var _texture: Texture2D
var _was_active := false
var _pinned_origin: Variant = null  # Vector2i, set by --ghost
var _debug_house_origin: Variant = null  # Vector2i, set by --house


## Shows the ghost with snow on its roof, as a house looks while there is snow about.
func set_snowy(is_snowy: bool) -> void:
	_is_snowy = is_snowy


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ghost="):
			_pinned_origin = _parse_tile(arg)
		elif arg.begins_with("--house="):
			_debug_house_origin = _parse_tile(arg)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	if event.is_action_pressed("build_previous"):
		builder.pick(-1)
	elif event.is_action_pressed("build_next"):
		builder.pick(1)
	elif event.is_action_pressed("use") or event.is_action_pressed("use_click"):
		_place()
	elif (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_RIGHT
	):
		builder.dismiss()
		message_changed.emit("")
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if world == null:
		return
	if _debug_house_origin != null and _is_footprint_loaded(_debug_house_origin):
		if world.place_building(builder.choice, _debug_house_origin) == null:
			push_error("--house: can't place a house at %s" % _debug_house_origin)
		_debug_house_origin = null
	var is_now_active := is_active()
	if is_now_active != _was_active:
		_was_active = is_now_active
		queue_redraw()
		if not is_now_active:
			message_changed.emit("")
	if not is_now_active:
		return
	_origin = (
		_pinned_origin if _pinned_origin != null else _origin_under(camera.mouse_world_position())
	)
	_texture = load(
		SeasonalArt.house_path(BuildingTypes.TYPES[builder.choice]["sprite"], _is_snowy)
	)
	_blockers = world.placement_blockers(builder.choice, _origin)
	_show_message()
	queue_redraw()


func _draw() -> void:
	if not is_active():
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


## The tile of a `--flag=<x>,<y>` argument, or null (after an error) if it is malformed.
func _parse_tile(arg: String) -> Variant:
	var value := arg.get_slice("=", 1)
	var parts := value.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_error("%s expects <x>,<y>, got '%s'" % [arg.get_slice("=", 0), value])
		return null
	return Vector2i(int(parts[0]), int(parts[1]))
