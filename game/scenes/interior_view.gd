class_name InteriorView
extends Node2D
## Renders an Interior from its state, in 3/4 view: the floor and walls on one tile layer,
## the furniture as sprites in the y-sorted `entities` node, where the player stands among
## them. Beds lie on the floor, below the player; one the player lies in has its cover (the
## blanket) drawn over them (see `cover_bed`). Furniture that shines (the hearth) gets an
## ObjectLight, and its fire burns (see AmbientMotion).
##
## The room is walled in by its WALL tiles: along the top a back wall face of BACK_WALL_ROWS
## tiles, on the other sides thin tops of walls, 8 px wide, drawn on the half of the wall
## tile next to the room. Which picture a wall tile gets follows from where it is, so the
## state only needs to say floor or wall. Tiles come from assets/interior.png, the same image
## the Tiled tileset (maps/interiors/interior.tsx) uses; the order of `Ground` is the order
## of its cells (see the art generator). Furniture pictures are in assets/interior/. All are
## loaded in the chosen art set (see ArtSet).

enum Ground {
	FLOOR,
	FLOOR_SHADED,
	CLAY_FLOOR,
	CLAY_FLOOR_SHADED,
	RIM_LEFT,
	RIM_RIGHT,
	RIM_FRONT,
	FRONT_LEFT,
	FRONT_RIGHT,
	DOORMAT,
	BACK_TOP,
	BACK_BOTTOM,
	BACK_LEFT_TOP,
	BACK_LEFT_BOTTOM,
	BACK_RIGHT_TOP,
	BACK_RIGHT_BOTTOM,
}

const ATLAS_PATH := "res://assets/interior.png"
const SOURCE_ID := 0
const BACK_WALL_ROWS := 2
## Beyond the room, so it does not show the (hidden) world's emptiness.
const BACKDROP := Color("1d1b26")
const BACKDROP_RADIUS := 1000.0

## Y-sorted: the player is added here.
var entities := Node2D.new()
## The beds, which are under everything that stands in the room.
var _beds := Node2D.new()
var _ground := TileMapLayer.new()
var _atlas := TileSetAtlasSource.new()
## The interior shown, to show it anew in the other art set.
var _interior: Interior
var _is_redraw_queued := false
## The furniture sprites and the lights, to be replaced when another interior is shown.
var _furniture: Array[Node] = []
## The covers of the beds that have one, by the bed's tile; shown while the player lies in it.
var _covers := {}


func _ready() -> void:
	add_to_group(ArtSet.VIEWS)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TerrainTileset.TILE_SIZE, TerrainTileset.TILE_SIZE)
	_atlas.texture = load(ArtSet.path(ATLAS_PATH))
	_atlas.texture_region_size = tile_set.tile_size
	tile_set.add_source(_atlas, SOURCE_ID)
	for column in _atlas.texture.get_width() / TerrainTileset.TILE_SIZE:
		_atlas.create_tile(Vector2i(column, 0))
	_ground.name = "Ground"
	_ground.tile_set = tile_set
	add_child(_ground)
	_beds.name = "Beds"
	add_child(_beds)
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)


## Shows the room in the chosen art set (see ArtSet): both sets have the same tiles.
func show_art_set() -> void:
	_atlas.texture = load(ArtSet.path(ATLAS_PATH))
	if _interior != null:
		show_interior(_interior)


## Shows a room, and redraws it whenever its tiles or objects change. Showing another room lets go
## of the old one.
func show_interior(interior: Interior) -> void:
	if _interior != interior:
		if _interior != null:
			_interior.objects_changed.disconnect(_on_room_changed)
			_interior.tile_changed.disconnect(_on_room_changed)
		_interior = interior
		_interior.objects_changed.connect(_on_room_changed)
		_interior.tile_changed.connect(_on_room_changed)
	_draw_room()


## An object covers several tiles and tells of each: the room is drawn once, after all of them.
func _on_room_changed(_pos: Vector2i) -> void:
	if not _is_redraw_queued:
		_is_redraw_queued = true
		_draw_room.call_deferred()


func _draw_room() -> void:
	_is_redraw_queued = false
	var interior := _interior
	_ground.clear()
	for node in _furniture:
		node.queue_free()
	_furniture.clear()
	_covers.clear()
	for y in interior.size.y:
		for x in interior.size.x:
			var pos := Vector2i(x, y)
			var tile := interior.tile_at(pos)
			if tile != null:
				var ground := ground_at(tile, pos, interior.size, pos == interior.exit_tile)
				_ground.set_cell(pos, SOURCE_ID, Vector2i(ground, 0))
	for object in interior.objects():
		_add_furniture(object)


## Draws the cover of the bed the player lies in over them, and no other; null for a player on
## their feet.
func cover_bed(bed: WorldObject) -> void:
	for pos: Vector2i in _covers:
		_covers[pos].visible = bed != null and bed.pos == pos


func _draw() -> void:
	draw_rect(Rect2(Vector2.ONE * -BACKDROP_RADIUS, Vector2.ONE * 2 * BACKDROP_RADIUS), BACKDROP)


## Which ground picture a tile of a room of this size gets.
static func ground_at(tile: Tile, pos: Vector2i, size: Vector2i, is_exit: bool) -> Ground:
	if is_exit:
		return Ground.DOORMAT
	if tile.is_floor():
		# The row along the back wall lies in its shadow.
		var is_shaded := pos.y == BACK_WALL_ROWS
		if tile.terrain == Tile.Terrain.CLAY_FLOOR:
			return Ground.CLAY_FLOOR_SHADED if is_shaded else Ground.CLAY_FLOOR
		return Ground.FLOOR_SHADED if is_shaded else Ground.FLOOR
	var is_left := pos.x == 0
	var is_right := pos.x == size.x - 1
	if pos.y < BACK_WALL_ROWS:
		var is_lower := pos.y == BACK_WALL_ROWS - 1
		if is_left:
			return Ground.BACK_LEFT_BOTTOM if is_lower else Ground.BACK_LEFT_TOP
		if is_right:
			return Ground.BACK_RIGHT_BOTTOM if is_lower else Ground.BACK_RIGHT_TOP
		return Ground.BACK_BOTTOM if is_lower else Ground.BACK_TOP
	if pos.y == size.y - 1:
		if is_left:
			return Ground.FRONT_LEFT
		return Ground.FRONT_RIGHT if is_right else Ground.RIM_FRONT
	return Ground.RIM_LEFT if is_left else Ground.RIM_RIGHT


func _add_furniture(object: WorldObject) -> void:
	var object_type: Dictionary = WorldObjectTypes.TYPES[object.type]
	var tile_size := TerrainTileset.TILE_SIZE
	var footprint: Vector2i = object_type["footprint"]
	var texture: Texture2D = load(ArtSet.path(object_type["interior_sprite"]))
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	# Sorted by the middle of the bottom footprint row, like the objects outside. The picture
	# is centred on the footprint, its bottom edge on the footprint's.
	sprite.position = Vector2(
		(object.pos.x + footprint.x / 2.0) * tile_size,
		(object.pos.y + footprint.y - 0.5) * tile_size
	)
	sprite.offset = Vector2(-texture.get_width() / 2.0, tile_size / 2.0 - texture.get_height())
	if AmbientMotion.has_flames(object.type):
		sprite.material = AmbientMotion.fire_material(object.type)
	(_beds if object.is_bed() else entities).add_child(sprite)
	_furniture.append(sprite)
	if object_type.has("interior_cover"):
		var cover := Sprite2D.new()
		cover.texture = load(ArtSet.path(object_type["interior_cover"]))
		cover.centered = false
		cover.position = sprite.position
		cover.offset = sprite.offset
		cover.z_index = PlayerView.COVER_Z_INDEX
		cover.visible = false
		_beds.add_child(cover)
		_furniture.append(cover)
		_covers[object.pos] = cover
	if not object.light().is_empty():
		var light := ObjectLight.new(object.light(), object.pos)
		# The fire, a bit above the middle of the footprint: it burns at the back of the hearth.
		light.position = (
			(Vector2(object.pos) + Vector2(footprint) / 2.0) * tile_size + Vector2(0, -8)
		)
		add_child(light)
		_furniture.append(light)
