class_name WorldObjectView
extends Node2D
## What a World's objects look like: a TileMapLayer on the plain tile grid that draws them, in the
## y-sorted `entities` node of WorldView, where the player and the creatures stand among them.
## WorldView owns it, tells it which tile changed and gives it the looks of the day.
##
## Objects that shine get an ObjectLight. Plants, water, fires and lily pads move in the wind by
## the materials of `ambient_motion`.
##
## See-through: while a tree hides the player (see Occlusion) it fades inside a circle around the
## player. A cell of the layer can't fade, so while the tree occludes (and while it fades back) its
## cell is erased and a SeeThroughSprite at the same place in the y-sorted node draws it instead.
## A shaking object and a falling tree are such sprites too.

## An object state (see `_states`) for a plant that is dormant and not drawn.
const DORMANT := -1
## Added to an object state for a bush that is out of its fruit season.
const BARE_OF_FRUIT_FLAG := 16

var tileset: ObjectTileset
## The object cells, by tile.
var cells := TileMapLayer.new()
## The looks of the day (see SeasonBlend), which WorldView sets with `set_looks`.
var _blend: SeasonBlend
var _conditions: SeasonBlend.Conditions
## The look of the turf objects (the dyke): the ground's, the same for all of them.
var _turf_look: SeasonBlend.Look
var _world: World
var _ambient_motion: AmbientMotion
var _light_strength := 1.0
## The light of each shining object, by tile.
var _lights: Dictionary[Vector2i, ObjectLight] = {}
## What each object cell was last drawn as, by tile: its look, plus BARE_OF_FRUIT_FLAG if it
## showed as bare of fruit, or DORMANT if it was not drawn.
var _states: Dictionary[Vector2i, int] = {}
## Which picture of the wind-blown scarecrow is shown (see AmbientMotion `scarecrow_frame`).
var _scarecrow_frame := 0
## The sprites that stand in for object cells while they are see-through, by tile.
var _sprites: Dictionary[Vector2i, SeeThroughSprite] = {}
## The tiles whose object is not drawn, as a tree is about to lie down as its trunk there.
var _hidden_tiles: Dictionary[Vector2i, bool] = {}
var _entities: Node2D


func _init(entities: Node2D, ambient_motion: AmbientMotion, ground_look: GroundLook) -> void:
	_entities = entities
	_ambient_motion = ambient_motion
	tileset = ObjectTileset.new(CropRules.default_rules(), ambient_motion)
	cells.name = "Objects"
	cells.tile_set = tileset.tile_set
	cells.y_sort_enabled = true
	cells.material = ground_look.objects
	entities.add_child(cells)


func show_art_set() -> void:
	tileset.show_art_set()


func show_world(world: World) -> void:
	_world = world


## Sets the looks the objects are drawn for (see SeasonBlend). Objects already drawn change
## when `is_stale` says so.
func set_looks(
	blend: SeasonBlend, conditions: SeasonBlend.Conditions, turf_look: SeasonBlend.Look
) -> void:
	_blend = blend
	_conditions = conditions
	_turf_look = turf_look


## The look of whatever is drawn at a tile, which changes on a day of its own for each tile.
func tile_look(world_pos: Vector2i) -> SeasonBlend.Look:
	return _conditions.foliage_season_look(_blend.season_threshold(world_pos))


## The look of an object: of the foliage of its season, which each tree and bush changes to on a
## day of its own (see SeasonBlend); turf has the ground's. The frost and snow lie over it by the
## shader.
func look_of(object: WorldObject) -> SeasonBlend.Look:
	if object.type_data().get("turf", false):
		return _turf_look
	return tile_look(object.pos)


## Whether an object is drawn differently now than it was last drawn.
func is_stale(object: WorldObject) -> bool:
	return _states.get(object.pos, DORMANT) != _object_state(object)


## Sets how brightly every light shines (see ObjectLight.strength).
func set_light_strength(strength: float) -> void:
	_light_strength = strength
	for light in _lights.values():
		light.strength = strength


## Draws the objects of a chunk.
func draw_chunk(chunk: Chunk) -> void:
	for object in chunk.objects():
		draw(object.pos)


## Draws the object on a tile again (or erases the tile's cell if there is none).
func draw(world_pos: Vector2i) -> void:
	var object := _world.object_at(world_pos)
	_remove_light(world_pos)
	if object == null or _hidden_tiles.has(world_pos):
		cells.erase_cell(world_pos)
		_states.erase(world_pos)
		return
	if _sprites.has(world_pos):
		# A stand-in sprite is showing it (the player stands behind it before its chunk is
		# drawn): the cell stays empty until the sprite goes, and the sprite shows it as it is now.
		place_sprite(_sprites[world_pos], object)
		_states[world_pos] = _object_state(object)
	else:
		_set_cell(object)
	if not object.light().is_empty():
		var light := ObjectLight.new(object.light(), world_pos)
		light.strength = _light_strength
		_lights[world_pos] = light
		add_child(light)


## Draws the object on a tile again, in its cell even if a stand-in sprite showed it.
func redraw(world_pos: Vector2i) -> void:
	_drop_sprite(world_pos)
	draw(world_pos)


## Keeps the object on a tile from being drawn, until `reveal`.
func hide_object(world_pos: Vector2i) -> void:
	_hidden_tiles[world_pos] = true
	redraw(world_pos)


## Draws the object on a tile again after `hide_object`, if its chunk is still loaded.
func reveal(world_pos: Vector2i) -> void:
	_hidden_tiles.erase(world_pos)
	if _world.is_chunk_loaded(Chunk.world_to_chunk(world_pos)):
		draw(world_pos)


## Erases the objects of a chunk that was dropped from the world.
func forget_chunk(chunk: Chunk) -> void:
	for object in chunk.objects():
		_drop_sprite(object.pos)
		cells.erase_cell(object.pos)
		_states.erase(object.pos)
		_remove_light(object.pos)


## Shows the scarecrows in the picture the wind gives them now, redrawing them when it changes.
func sway_scarecrows() -> void:
	var frame := _ambient_motion.scarecrow_frame()
	if frame == _scarecrow_frame:
		return
	_scarecrow_frame = frame
	for scarecrow in _world.scarecrows():
		if _world.is_chunk_loaded(Chunk.world_to_chunk(scarecrow.pos)):
			draw(scarecrow.pos)


## Shakes an object: as a sprite, since a cell of the objects layer can't move alone.
func shake(object: WorldObject) -> void:
	if _hidden_tiles.has(object.pos):
		return
	if not _sprites.has(object.pos):
		_swap_cell_for_sprite(object)
	_sprites[object.pos].shake()


## Fades what hides the player and puts back what no longer does.
func update_see_through(delta: float, player_feet: Vector2, player_size: Vector2) -> void:
	for sprite in _sprites.values():
		sprite.is_occluding = false
	for object in Occlusion.occluding_objects(player_feet, _world, player_size):
		if not _sprites.has(object.pos):
			_swap_cell_for_sprite(object)
		_sprites[object.pos].is_occluding = true
	for pos in _sprites.keys():
		var sprite := _sprites[pos]
		sprite.update(delta, player_feet)
		if sprite.is_plain():
			_drop_sprite(pos)
			_set_cell(_world.object_at(pos))


## Gives a sprite the picture of an object as it looks now, at the place and sorted the same way
## as the tile map draws it (see ObjectTileset): sorted by the middle of the footprint's bottom
## row, the cell's bottom on the footprint's bottom edge.
func place_sprite(sprite: Sprite2D, object: WorldObject) -> void:
	var cell_size := _picture_size(object)
	sprite.texture = _object_texture(object)
	sprite.centered = false
	var footprint: Vector2i = WorldObjectTypes.TYPES[object.type]["footprint"]
	# The ground it stands on: the middle of the tile at the foot of its cell.
	SeeThroughSprite.show_cover(
		sprite,
		Vector2(
			(object.pos.x + footprint.x / 2.0) * TerrainTileset.TILE_SIZE,
			(object.pos.y + footprint.y - 0.5) * TerrainTileset.TILE_SIZE
		)
	)
	var sort_shift := Vector2(0, (footprint.y - 1) * TerrainTileset.TILE_SIZE)
	sprite.position = TerrainTileset.tile_centre(object.pos)
	sprite.position += sort_shift
	sprite.offset = (
		-Vector2(cell_size) / 2 - Vector2(ObjectTileset.cell_origin(footprint)) - sort_shift
	)


func _set_cell(object: WorldObject) -> void:
	cells.set_cell(object.pos, _object_source(object), _atlas_cell(object))
	_states[object.pos] = _object_state(object)


## The source that an object is drawn from: its own sheet for a crop, else the object atlas in
## its look.
func _object_source(object: WorldObject) -> int:
	if object.is_crop():
		return tileset.crop_source_id(object.type)
	return look_of(object)


## What an object is drawn as: its look, with a flag if it is out of its fruit season, or
## DORMANT if it is not drawn. A change of the state means the cell must be drawn again. A crop
## has the same look all year; its growth comes through `objects_changed`.
func _object_state(object: WorldObject) -> int:
	if object.is_crop():
		return 0
	if _world.is_dormant(object):
		return DORMANT
	return look_of(object) + (BARE_OF_FRUIT_FLAG if _world.is_bare(object) else 0)


## The object's cell in its source as it looks now (see ObjectTileset.atlas_cell).
func _atlas_cell(object: WorldObject) -> Vector2i:
	var object_type := object.type_data()
	var connections := _world.connections(object) if object_type.has("connects") else 0
	var slanted := (
		LineSlants.slanted_sides(_world, object) if object_type.get("slants", false) else 0
	)
	return ObjectTileset.atlas_cell(
		object, _world.is_bare(object), connections, _scarecrow_frame, slanted, _dyke_look(object)
	)


## The look of a dyke's picture, which follows the dyke's profile and whether a flood tore it;
## empty for every other object.
func _dyke_look(object: WorldObject) -> StringName:
	if object.type != WorldObjectTypes.DYKE:
		return &""
	return _world.dykes.look(object, _world.flood.is_torn(object.pos))


## The picture of an object as it looks now, for its stand-in sprite.
func _object_texture(object: WorldObject) -> AtlasTexture:
	var cell_size := Vector2i(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
	var texture := AtlasTexture.new()
	texture.atlas = load(ObjectTileset.picture(look_of(object)))
	texture.region = Rect2(_atlas_cell(object) * cell_size, _picture_size(object))
	return texture


## The size of an object's picture in the atlas: a cell, or `cells_wide` of them.
func _picture_size(object: WorldObject) -> Vector2i:
	var cells_wide: int = object.type_data().get("cells_wide", 1)
	return Vector2i(cells_wide * ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)


## Erases an object's cell and draws the same picture as a sprite, sorted the same way.
func _swap_cell_for_sprite(object: WorldObject) -> void:
	var sprite := SeeThroughSprite.new()
	place_sprite(sprite, object)
	_entities.add_child(sprite)
	_sprites[object.pos] = sprite
	cells.erase_cell(object.pos)


## Frees the stand-in sprite of an object, if it has one. The caller sets the cell.
func _drop_sprite(world_pos: Vector2i) -> void:
	var sprite: SeeThroughSprite = _sprites.get(world_pos)
	if sprite != null:
		_sprites.erase(world_pos)
		sprite.queue_free()


func _remove_light(world_pos: Vector2i) -> void:
	var light: ObjectLight = _lights.get(world_pos)
	if light != null:
		_lights.erase(world_pos)
		light.queue_free()
