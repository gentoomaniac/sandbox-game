class_name TravelView
extends RefCounted
## What a search for a villager's way sees of the tiles of a World, near or far (see
## design/villagers/travel.md): whether a villager can stand on a tile (`is_free`), what stepping
## onto it costs (`cost_of`) and whether those can be answered yet (`is_known`).
##
## A tile is answered live, by the world, where its chunk and the chunks W, N and NW of it are
## loaded (a big object reaches east and south from its own tile, so the world sees all of what
## covers a tile only then), and by the TravelMask of its chunk everywhere else, which is not
## there until `TravelMasks` has made it. So a chunk loading or unloading changes no answer. Both
## answer for one time, `at_minutes`, the tide and the season of the walk and not of the clock.
## Buildings are the world's, always: the tiles of one, the door included, are closed.

## The chunks a tile's live answer needs loaded, relative to its own.
const LIVE_CHUNKS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]

var _world: World
var _masks: TravelMasks
var _at_minutes: int
var _day: int
var _tide_level: float
var _cost_trodden: float
var _cost_path: float
var _cost_object: float


## The costs are those of `rules` ([travel] of data/npcs.cfg).
func _init(world: World, masks: TravelMasks, rules: NpcRules, at_minutes: int) -> void:
	_world = world
	_masks = masks
	_at_minutes = at_minutes
	_day = GameClock.day_of(at_minutes)
	_tide_level = Tide.level(at_minutes)
	_cost_trodden = rules.travel("cost_trodden")
	_cost_path = rules.travel("cost_path")
	_cost_object = rules.travel("cost_object")


## Whether the world answers for a tile itself (see above), and no mask is needed.
func is_live(tile: Vector2i) -> bool:
	var coords := Chunk.world_to_chunk(tile)
	for step in LIVE_CHUNKS:
		var needed := coords + step
		if World.is_chunk_in_bounds(needed) and not _world.is_chunk_loaded(needed):
			return false
	return true


## Whether `is_free` and `cost_of` can answer for the tile. If not, its mask is asked for. A tile
## outside the world is known: nobody can stand there.
func is_known(tile: Vector2i) -> bool:
	if not World.is_in_bounds(tile):
		return true
	return is_live(tile) or _masks.mask_of(Chunk.world_to_chunk(tile)) != null


## Whether a villager can stand on the tile, at the time of the view. Only for a known tile.
func is_free(tile: Vector2i) -> bool:
	if not World.is_in_bounds(tile) or _world.building_at(tile) != null:
		return false
	if is_live(tile):
		return _world.is_walkable_at(tile, _at_minutes)
	var mask := _masks.mask_of(Chunk.world_to_chunk(tile))
	return mask != null and mask.is_free(Chunk.local_pos(tile), _tide_level, _day)


## What stepping onto the tile costs: 1.0 on ordinary ground, less on worn grass (the lanes), so
## villagers keep to what others have walked, and more where something that feet spoil stands (a
## crop, a flower), so they walk round the fields. Only for a known tile.
func cost_of(tile: Vector2i) -> float:
	var cost := 1.0
	match _world.wear_stage(tile):
		PathRules.Stage.TRODDEN:
			cost = _cost_trodden
		PathRules.Stage.PATH:
			cost = _cost_path
	if _is_trampled(tile):
		cost += _cost_object
	return cost


func _is_trampled(tile: Vector2i) -> bool:
	if is_live(tile):
		var object := _world.object_on(tile, _day)
		return object != null and NpcTravel.is_trampled(object)
	var mask := _masks.mask_of(Chunk.world_to_chunk(tile))
	return mask != null and mask.is_trampled(Chunk.local_pos(tile), _day)
