class_name WorldView
extends Node2D
## Renders a World, drawing the chunks that a ChunkResidency loads and erasing those it drops.
##
## It is the composition and the invalidation boundary: it follows the signals of the world and
## the residency, tells the presenters what changed, and spends the one budget of a frame (the
## ground's chunk drawing first, the look refresh only in frames without drawing; `is_settled`
## says when both are done). The presenters draw:
## - TerrainChunkView: the terrain layers, a dual grid for the whole world (see TerrainTileset),
##   the chunk draw and refresh queues, and the CoverMap.
## - DecorationView, on the plain tile grid: flowers, pebbles and the like, none under an object.
## - SoilWetness: the damp or wet look of tilled soil, over the soil terrain.
## - WorldObjectView: the world's objects, in the y-sorted `entities` node, where the player (and
##   the creatures) stand among them, with their lights and the see-through stand-in sprites.
## - TreeFallEffects: a felled tree topples as a FallingTree sprite while the state already has
##   its stump and its trunk.
## - BuildingViews: the buildings, sprites in `entities` too, so they sort with the objects and
##   the player.
## Plants, water, fires and lily pads move in the wind by the materials of `ambient_motion`, and
## the rain splashes on the ground under the objects.
##
## See-through: while a tree or building hides the player (see Occlusion) it fades inside a
## circle around the player (see WorldObjectView and BuildingViews).

## A tree was felled and starts to fall, for `seconds` until it lands.
signal tree_felled(tile: Vector2i, seconds: float)
## A felled tree hit the ground (where the sound of it belongs). `tree` is the object it was.
signal tree_landed(tree: WorldObject)

## The lower part of a tree's canopy, as a share of its picture's height above the picture's
## bottom: what falls from there passes the trunk and shows against the ground.
const CANOPY_HEIGHT_SHARE := 0.45
## The tiles whose line objects may look different once an object on a tile changes: those beside
## it, and for a line that slants (see LineSlants) the others up to two steps away.
const _LINE_REDRAW_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(0, -2),
	Vector2i(2, 0),
	Vector2i(0, 2),
	Vector2i(-2, 0),
]

var world: World
## Y-sorted: whatever is added here is drawn in front of or behind the objects by its y.
var entities := Node2D.new()
## True once every chunk around the focus is loaded.
var is_settled := false
## Where the player stands, in world pixels, and how big they are (see Occlusion; both set by the
## game scene every frame).
var player_feet := Vector2.ZERO
var player_size := Occlusion.PLAYER_SIZE
## The game scene gives it the wind and the rain every frame.
var ambient_motion := AmbientMotion.new()
## The flowers and pebbles on the ground and the hints of clay spots; the wildlife asks it where
## flowers bloom.
var decorations: DecorationView
var _residency: ChunkResidency
var _hit_particles := HitParticles.new()
var _falling_leaves := FallingLeaves.new()
var _terrain: TerrainChunkView
var _object_view: WorldObjectView
var _soil_wetness := SoilWetness.new()
var _footprint_view := FootprintView.new()
var _flood_overlay := FloodOverlay.new(ambient_motion.flood)
## The rims of trodden earth beside the ways, under the objects.
var _way_edges: WayEdges
var _light_strength := 1.0
var _blend: SeasonBlend
## The colour of the ground and what lies on it (see GroundLook and CoverMap).
var _ground_look: GroundLook
## The day that the decorations, plants and houses are drawn for.
var _look_day := -1
var _conditions: SeasonBlend.Conditions
var _tree_falls: TreeFallEffects
var _buildings := BuildingViews.new(entities)


func _init() -> void:
	_ground_look = GroundLook.new(ambient_motion.decoration_sway, ambient_motion.ford)
	_terrain = TerrainChunkView.new(ambient_motion, _ground_look)
	_object_view = WorldObjectView.new(entities, ambient_motion, _ground_look)
	_tree_falls = TreeFallEffects.new(entities, _object_view, _hit_particles)
	_tree_falls.tree_felled.connect(tree_felled.emit)
	_tree_falls.tree_landed.connect(tree_landed.emit)
	decorations = DecorationView.new(_terrain.tileset)
	decorations.show_ground_look(_ground_look)


func _ready() -> void:
	add_to_group(ArtSet.VIEWS)
	add_child(_terrain)
	# Wet soil lies right over the soil terrain, and clears where snow lies on it.
	_soil_wetness.show_ground_look(_ground_look)
	add_child(_soil_wetness)
	add_child(_footprint_view)
	add_child(_flood_overlay)
	add_child(decorations)
	add_child(RainSplashes.new(ambient_motion))
	_way_edges = WayEdges.new(_object_view.tileset.tile_set, _ground_look.objects)
	add_child(_way_edges.layer)
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	add_child(_object_view)
	add_child(_tree_falls)
	add_child(_hit_particles)
	add_child(_falling_leaves)
	add_child(_buildings)


## Shows the ground, the objects and the crops, the campfires' flames and the buildings in the
## chosen art set (see ArtSet).
func show_art_set() -> void:
	_terrain.show_art_set()
	_object_view.show_art_set()
	_soil_wetness.show_art_set()
	ambient_motion.show_art_set()
	_ground_look.show_art_set()
	_buildings.show_art_set()


## Shows the world of a residency, including the chunks that are already loaded in it, and draws
## the chunks it loads from now on. Showing the residency it shows again does nothing; another
## one is refused, as its chunks, objects and houses would stay drawn: make a new view.
func show_world(residency: ChunkResidency) -> void:
	if _residency == residency:
		return
	if _residency != null:
		push_error("WorldView already shows another world")
		return
	_residency = residency
	world = residency.world
	# The view was made before Main chose the art set.
	show_art_set()
	_object_view.show_world(world)
	_tree_falls.show_world(world)
	_way_edges.show_world(world, _object_view.tile_look)
	world.objects_changed.connect(_on_objects_changed)
	world.tile_changed.connect(redraw_tile)
	_terrain.show_world(residency, decorations, _way_edges)
	_terrain.objects_due.connect(_object_view.draw_chunk)
	_terrain.chunk_refreshed.connect(_refresh_objects_of)
	decorations.cover_map = _terrain.cover_map
	world.object_hit.connect(_on_object_hit)
	world.clay_spot_changed.connect(_on_clay_spot_changed)
	_soil_wetness.show_world(world)
	_footprint_view.show_world(world, _terrain.cover_map.is_snowed)
	_flood_overlay.show_world(world, residency)
	world.building_placed.connect(_buildings.add)
	world.building_placed.connect(_on_building_changed)
	world.building_removed.connect(_buildings.remove)
	world.building_removed.connect(_on_building_changed)
	world.bell_rung.connect(_buildings.swing_bell)
	residency.chunk_loaded.connect(_terrain.on_chunk_loaded)
	residency.chunk_unloaded.connect(_on_chunk_unloaded)
	decorations.show_world(world)
	_blend = SeasonBlend.new(world.world_seed)
	decorations.day = world.clock.day
	_conditions = _blend.conditions(decorations.day)
	_look_day = decorations.day
	_object_view.set_looks(_blend, _conditions, _blend.turf_look(decorations.day))
	_buildings.set_looks(_blend, _conditions)
	show_ground_cover(decorations.day, 0.0, 0.0, 0.0)
	_terrain.sync_cover_focus()
	for coords in world.loaded_chunk_coords():
		_terrain.draw_chunk(world.chunk_at(coords))
	for building in world.buildings():
		_buildings.add(building)


## Shows the ground of a day in the weather of a moment: its colour of the time of year, and the
## fallen leaves, the frost (0 to 1) and the snow cover and the thaw (0 to 1) over it. Cheap, a few
## numbers for the shaders, so the world calls it every game minute and the cover builds up and
## melts evenly.
func show_ground_cover(day: int, snow_cover: float, thaw: float, frost: float) -> void:
	_ground_look.show_mix(_blend.ground_mix(day))
	_terrain.cover_map.set_weather(_blend.litter(day), snow_cover, thaw, frost)


## Sets the day that the decorations, plants and houses are drawn for, which changes the season's
## look of each on a day of its own. Does nothing while it is the same day; otherwise every loaded
## chunk is queued for a refresh, which `_process` does a few chunks per frame (chunks that load
## later are drawn for it right away).
func refresh_looks(day: int) -> void:
	if world == null or day == _look_day:
		return
	_look_day = day
	decorations.day = day
	_conditions = _blend.conditions(day)
	_object_view.set_looks(_blend, _conditions, _blend.turf_look(day))
	_terrain.queue_refresh()
	_buildings.set_looks(_blend, _conditions)


## The picture a building is shown with now, unlit (the roof is the same lit or not).
func building_picture(building: Building) -> String:
	return _buildings.picture_path(building)


## Whether a loaded chunk is not drawn yet.
func is_drawing() -> bool:
	return _terrain.is_drawing()


## Draws the chunks that are loaded and not drawn yet, at once (for tests).
func finish_drawing() -> void:
	_terrain.finish_drawing()


## Brings every queued chunk up to date at once (for tests).
func finish_refresh() -> void:
	_terrain.finish_refresh()


## Redraws one tile after its state changed. World's `tile_changed` calls it.
func redraw_tile(world_pos: Vector2i) -> void:
	_terrain.redraw_tile(world_pos)


## How brightly the lights shine now (see ObjectLight.strength).
func light_strength() -> float:
	return _light_strength


## Sets how fast the sails of the windmills turn (see SailTurn).
func set_sail_speed(speed: float) -> void:
	_buildings.set_sail_speed(speed)


## Sets how brightly every light shines (see ObjectLight.strength).
func set_light_strength(strength: float) -> void:
	_light_strength = strength
	_object_view.set_light_strength(strength)
	_buildings.set_light_strength(strength)


## The soil of the loaded chunks shows the moisture it has now, and the rain of the hour that has
## just ended on its surface (see SoilWetness), those around the focus first: it changes with the
## hours, quietly, and a few tiles are drawn every frame. Chunks that load later are drawn when
## they load.
func refresh_soil(last_hour_rain: float) -> void:
	if world == null:
		return
	var coords := world.loaded_chunk_coords()
	var focus := _residency.focus_chunk
	coords.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (a - focus).length_squared() < (b - focus).length_squared()
	)
	_soil_wetness.refresh_looks(coords, last_hour_rain)


## Fades what hides the player and puts back what no longer does.
func _update_see_through(delta: float) -> void:
	_object_view.update_see_through(delta, player_feet, player_size)
	_buildings.update_see_through(
		delta,
		player_feet,
		Occlusion.occluding_buildings(player_feet, world.buildings(), player_size)
	)


func _process(delta: float) -> void:
	if world == null:
		return
	_terrain.draw_within_budget()
	# Loading and drawing fill most of a frame, so the look refresh only runs in frames without.
	var is_drawn := _residency.is_complete and not _terrain.is_drawing()
	if is_drawn:
		_terrain.refresh_within_budget()
	is_settled = is_drawn and not _terrain.has_refresh_pending()
	_update_see_through(delta)
	_object_view.sway_scarecrows()
	_tree_falls.advance(delta)
	_shed_leaves(delta)


## Draws again the objects of a refreshed chunk whose look changed.
func _refresh_objects_of(chunk: Chunk) -> void:
	for object in chunk.objects():
		if _object_view.is_stale(object):
			_on_objects_changed(object.pos)


## Called for every tile an object covers; it is drawn from its own tile only.
func _on_objects_changed(world_pos: Vector2i) -> void:
	var object := world.object_at(world_pos)
	if object == null or object.pos == world_pos:
		_object_view.redraw(world_pos)
	decorations.redraw(world_pos, _terrain.layer_at(world_pos))
	# A way laid or taken up changes the edges of the free tiles beside it.
	if object == null or object.type_data().has("way"):
		_way_edges.draw_around(world_pos)
	_terrain.update_crown(world_pos, object != null and object.type in GroundCover.CROWNED)
	# The lines beside it may join it now, or no longer; a line that slants also turns on the
	# slant or straight again two tiles away (see LineSlants).
	for offset in _LINE_REDRAW_OFFSETS:
		var neighbour := world.object_at(world_pos + offset)
		if (
			neighbour != null
			and neighbour.pos == world_pos + offset
			and neighbour.type_data().has("connects")
			and (offset in World.CONNECTION_SIDES or neighbour.type_data().get("slants", false))
		):
			_object_view.redraw(neighbour.pos)


## A house was put up or taken down: its lee changes what lies behind it.
func _on_building_changed(building: Building) -> void:
	for tile in building.tiles():
		_terrain.cover_map.redraw_around(tile)


func _on_clay_spot_changed(world_pos: Vector2i) -> void:
	decorations.redraw(world_pos, _terrain.layer_at(world_pos))


## A tool hit an object: what it leaves, if any, shakes (a stump, after the last hit), and
## what flies off it depends on the look the object had. The finishing hit on a tree has it
## topple instead, and the stump shakes when it lands.
func _on_object_hit(object: WorldObject) -> void:
	if world.is_gone(object) and object.type_data().has("leaves"):
		_tree_falls.start(object, _hit_effect(object), player_feet.x)
		return
	_hit_particles.emit(_hit_effect(object), _hit_origin(object))
	var standing := world.object_at(object.pos)
	if standing != null:
		_object_view.shake(standing)


func _hit_effect(object: WorldObject) -> HitEffect.Kind:
	return HitEffect.kind_for(object.type, _object_view.look_of(object), is_snowed_over(object.pos))


## Lets the trees among a few tiles picked around the player shed leaves into the wind.
func _shed_leaves(delta: float) -> void:
	var centre := Vector2i((player_feet / TerrainTileset.TILE_SIZE).floor())
	for tile in _falling_leaves.tiles_to_look_at(delta, centre):
		var tree := world.object_at(tile)
		if tree == null:
			continue
		var look := _object_view.look_of(tree)
		var kind := HitEffect.kind_for(tree.type, look, is_snowed_over(tree.pos))
		_falling_leaves.shed(kind, look, world.clock.day, _hit_origin(tree), ambient_motion.wind)


## Where a hit object throws its particles, in world pixels: the canopy of a tree, else the
## middle of the object.
func _hit_origin(object: WorldObject) -> Vector2:
	var type_data := object.type_data()
	var footprint: Vector2i = type_data["footprint"]
	var middle := (Vector2(object.pos) + Vector2(footprint) / 2) * TerrainTileset.TILE_SIZE
	if not type_data.has("sprite_height"):
		return middle
	var bottom := (object.pos.y + footprint.y) * TerrainTileset.TILE_SIZE
	return Vector2(middle.x, bottom - CANOPY_HEIGHT_SHARE * type_data["sprite_height"])


## Erases a chunk that was dropped from the world.
func _on_chunk_unloaded(chunk: Chunk) -> void:
	_object_view.forget_chunk(chunk)
	_terrain.forget_chunk(chunk)
	_footprint_view.forget_chunk(chunk.coords)
	_way_edges.forget_chunk(chunk.coords)
	_tree_falls.end_falls_in(chunk.coords)


## Whether snow lies on most of a tile now (what hit effects ask).
func is_snowed_over(world_pos: Vector2i) -> bool:
	return world != null and _terrain.cover_map.ground_cover.is_snowed(world_pos)


## Whether snow lies on the ground under a point of the world, `position` in tiles, now.
func is_snow_drawn_at(position: Vector2) -> bool:
	return is_snowed_over(Vector2i(position.floor()))


## Tells whether snow lies on a tile with this snow cover (0 to 1, no thaw), as it will be drawn
## once the ground is shown for it: `func(world_pos: Vector2i) -> bool`.
func snow_checker_for(snow_cover: float) -> Callable:
	return func(world_pos: Vector2i) -> bool:
		return _terrain.cover_map.ground_cover.is_snowed_with(world_pos, snow_cover, 0.0)
