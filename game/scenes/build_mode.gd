class_name BuildMode
extends Node2D
## Placing a building. While active, a ghost of the building follows the mouse, snapped to
## tiles: green where it can be built, with the blocked tiles marked red. A left click
## places it, a right click or the toggle key cancels. The rules are World's.
##
## Debug flags (see `make screenshot`): `--ghost=<x>,<y>` starts in build mode with the
## ghost's top left tile pinned there; `--house=<x>,<y>` places a house there as soon as
## its chunks are loaded.

const BUILDING_TYPE := BuildingTypes.SMALL_HOUSE
const UNSAFE_LAND_MESSAGE := "This land doesn't look safe to build on."
const OCCUPIED_MESSAGE := "Something is in the way."

# Palette colours (see tools/art/generate.py).
const VALID_TINT := Color("82a352", 0.5)
const BLOCKED_TINT := Color("a8402e", 0.7)
const GHOST_MODULATE := Color(1, 1, 1, 0.7)

var world: World

var _is_active := false
var _origin := Vector2i.ZERO
var _blockers: Dictionary[Vector2i, World.Blocked] = {}
var _texture: Texture2D = load(BuildingTypes.TYPES[BUILDING_TYPE]["sprite"])
var _footprint: Vector2i = BuildingTypes.TYPES[BUILDING_TYPE]["footprint"]
var _pinned_origin: Variant = null  # Vector2i, set by --ghost
var _debug_house_origin: Variant = null  # Vector2i, set by --house

@onready var _message: Label = $Hud/Message


func _ready() -> void:
	_message.hide()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ghost="):
			_pinned_origin = _parse_tile(arg)
			_is_active = _pinned_origin != null
		elif arg.begins_with("--house="):
			_debug_house_origin = _parse_tile(arg)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build"):
		_set_active(not _is_active)
		get_viewport().set_input_as_handled()
	elif _is_active and event is InputEventMouseButton and event.pressed:
		# Clicks belong to build mode while it is active, not to the player's actions.
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_set_active(false)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if world == null:
		return
	if _debug_house_origin != null and _is_footprint_loaded(_debug_house_origin):
		if world.place_building(BUILDING_TYPE, _debug_house_origin) == null:
			push_error("--house: can't place a house at %s" % _debug_house_origin)
		_debug_house_origin = null
	if not _is_active:
		return
	_origin = (
		_pinned_origin if _pinned_origin != null else _origin_under(get_global_mouse_position())
	)
	_blockers = world.placement_blockers(BUILDING_TYPE, _origin)
	_show_message()
	queue_redraw()


func _draw() -> void:
	if not _is_active:
		return
	var tile_size := TerrainTileset.TILE_SIZE
	var top_left := Vector2(_origin * tile_size)
	var footprint_size := Vector2(_footprint * tile_size)
	draw_texture(
		_texture, top_left + Vector2(0, footprint_size.y - _texture.get_height()), GHOST_MODULATE
	)
	for pos in Building.footprint_tiles(BUILDING_TYPE, _origin):
		var tint := BLOCKED_TINT if _blockers.has(pos) else VALID_TINT
		draw_rect(Rect2(Vector2(pos * tile_size), Vector2(tile_size, tile_size)), tint)


func _set_active(is_active: bool) -> void:
	_is_active = is_active
	if not is_active:
		_message.hide()
		queue_redraw()


func _place() -> void:
	# World checks the rules again, so a ghost one frame behind can't place a blocked house.
	if world.place_building(BUILDING_TYPE, _origin) != null:
		_set_active(false)


## The footprint's top left tile when the cursor is on its middle.
func _origin_under(world_position: Vector2) -> Vector2i:
	var tile := Vector2i((world_position / TerrainTileset.TILE_SIZE).floor())
	return tile - _footprint / 2


func _show_message() -> void:
	if _blockers.is_empty():
		_message.hide()
		return
	var is_unsafe_land := _blockers.values().has(World.Blocked.TERRAIN)
	_message.text = UNSAFE_LAND_MESSAGE if is_unsafe_land else OCCUPIED_MESSAGE
	_message.show()


func _is_footprint_loaded(origin: Vector2i) -> bool:
	return Building.footprint_tiles(BUILDING_TYPE, origin).all(
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
