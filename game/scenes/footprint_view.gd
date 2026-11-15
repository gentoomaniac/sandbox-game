class_name FootprintView
extends Node2D
## Draws the footprints of the loaded chunks (see Footprints), under the objects and the player,
## over the ground. One MultiMesh a chunk, made when its first print comes and dropped with the
## chunk: a print is one instance written once, when it is made or when it vanishes, and it fades
## in the shader (footprints.gdshader) by the age of its kind, so a frame does nothing for them
## but hand on the two ages and check one chunk's prints for soft ground.

const TEXTURE_PATH := "res://assets/effects/footprints.png"
const TILE_SIZE := TerrainTileset.TILE_SIZE

var _footprints: Footprints
var _world: World
var _material := ShaderMaterial.new()
var _quad := QuadMesh.new()
var _texture: Texture2D
var _chunk_prints: Dictionary[Vector2i, MultiMeshInstance2D] = {}
var _shown_ages := Vector2(-1.0, -1.0)


func _init() -> void:
	name = "Footprints"
	_material.shader = preload("res://game/scenes/footprints.gdshader")
	_quad.size = Vector2(TILE_SIZE, TILE_SIZE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group(ArtSet.VIEWS)


## Draws the prints of a world. `is_snowed_at` is how the ground view tells whether snow lies on a
## tile (see GroundCover `is_snowed`).
func show_world(world: World, is_snowed_at: Callable) -> void:
	_world = world
	_footprints = world.footprints
	_footprints.is_snowed_at = is_snowed_at
	_footprints.printed.connect(_on_printed)
	var rules := FootprintRules.default_rules()
	_material.set_shader_parameter("snow_lasts_minutes", rules.snow_lasts_minutes())
	_material.set_shader_parameter("mud_lasts_minutes", rules.mud_lasts_minutes())
	show_art_set()


## Loads the sheet of the chosen art set (see ArtSet).
func show_art_set() -> void:
	_texture = load(ArtSet.path(TEXTURE_PATH))
	for prints in _chunk_prints.values():
		prints.texture = _texture


## Drops the prints of an unloaded chunk.
func forget_chunk(chunk_coords: Vector2i) -> void:
	_footprints.forget_chunk(chunk_coords)
	var prints: MultiMeshInstance2D = _chunk_prints.get(chunk_coords)
	if prints != null:
		prints.queue_free()
		_chunk_prints.erase(chunk_coords)


func _process(_delta: float) -> void:
	if _footprints == null:
		return
	var ages := Vector2(
		_footprints.age_of(Footprints.Kind.SNOW), _footprints.age_of(Footprints.Kind.MUD)
	)
	if ages != _shown_ages:
		_shown_ages = ages
		_material.set_shader_parameter("snow_age", ages.x)
		_material.set_shader_parameter("mud_age", ages.y)
	_footprints.check_next_chunk(_world)


func _on_printed(chunk_coords: Vector2i, slot: int) -> void:
	var ring := _footprints.ring_of(chunk_coords)
	var prints: MultiMeshInstance2D = _chunk_prints.get(chunk_coords)
	if prints == null:
		prints = _add_chunk_prints(chunk_coords, ring.born.size())
	var multimesh := prints.multimesh
	multimesh.visible_instance_count = ring.size
	var turn := ring.quarter_turns[slot] * PI / 2.0
	multimesh.set_instance_transform_2d(slot, Transform2D(turn, ring.position[slot] * TILE_SIZE))
	multimesh.set_instance_custom_data(slot, Color(ring.born[slot], ring.cell[slot], 0.0, 0.0))


func _add_chunk_prints(chunk_coords: Vector2i, capacity: int) -> MultiMeshInstance2D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.mesh = _quad
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	# Else the prints are culled by the box of the first one.
	var chunk_size := Vector3(Chunk.CHUNK_SIZE, Chunk.CHUNK_SIZE, 1.0) * TILE_SIZE
	var origin := Vector2(Chunk.to_world(chunk_coords, Vector2i.ZERO)) * TILE_SIZE
	multimesh.custom_aabb = AABB(Vector3(origin.x, origin.y, 0.0), chunk_size)
	var prints := MultiMeshInstance2D.new()
	prints.multimesh = multimesh
	prints.texture = _texture
	prints.material = _material
	add_child(prints)
	_chunk_prints[chunk_coords] = prints
	return prints
