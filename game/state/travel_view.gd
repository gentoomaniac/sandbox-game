class_name TravelView
extends RefCounted
## What a search for a villager's way sees of the tiles of a World (see
## design/villagers/travel.md): whether a villager can stand on a tile (`is_free`), what stepping
## onto it costs (`cost_of`) and whether those can be answered yet (`is_known`).
##
## The search runs on a worker thread, so the view holds only what does not change: the
## TravelMask of each chunk it has been given (`provide`), the TravelSnapshot of the buildings and
## the wear, and the tide and the day of one time, `at_minutes`: the search's start, not the
## clock. Loaded or not, a chunk is answered by its mask (the masks follow the world's edits, which
## drop them). A tile whose mask the view lacks is not known: the chunk is noted in `missing`, the
## search waits, and the main thread gives the masks with `provide` before the search is run again.
## `is_known`, `is_free` and `cost_of` are for the worker; `provide` and `missing` for the main
## thread, while no search runs on the view.
##
## How it all works: design/tech/pathfinding.md.

## How many chunks round the way `prefetch` looks at.
const PREFETCH_MARGIN := 2

var missing: Dictionary[Vector2i, bool] = {}

var _masks: Dictionary[Vector2i, TravelMask] = {}
var _snapshot: TravelSnapshot
var _path_rules: PathRules
var _day: int
var _tide_level: float
var _cost_trodden: float
var _cost_path: float
var _cost_object: float


## The costs are those of `rules` ([travel] of data/npcs.cfg).
func _init(snapshot: TravelSnapshot, rules: NpcRules, at_minutes: int) -> void:
	_snapshot = snapshot
	_path_rules = PathRules.default_rules()
	_day = GameClock.day_of(at_minutes)
	_tide_level = Tide.level(at_minutes)
	_cost_trodden = rules.travel("cost_trodden")
	_cost_path = rules.travel("cost_path")
	_cost_object = rules.travel("cost_object")


## Whether `is_free` and `cost_of` can answer for the tile. If not, its chunk is in `missing`. A
## tile outside the world is known: nobody can stand there.
func is_known(tile: Vector2i) -> bool:
	var coords := Chunk.world_to_chunk(tile)
	if not World.is_chunk_in_bounds(coords) or _masks.has(coords):
		return true
	missing[coords] = true
	return false


## Whether a villager can stand on the tile, at the time of the view. Only for a known tile.
func is_free(tile: Vector2i) -> bool:
	var mask: TravelMask = _masks.get(Chunk.world_to_chunk(tile))
	return (
		mask != null
		and not _snapshot.buildings.has(tile)
		and mask.is_free(Chunk.local_pos(tile), _tide_level, _day)
	)


## What stepping onto the tile costs: 1.0 on ordinary ground, less on worn grass (the lanes), so
## villagers keep to what others have walked, and more where something that feet spoil stands (a
## crop, a flower), so they walk round the fields. Only for a known tile.
func cost_of(tile: Vector2i) -> float:
	var cost := 1.0
	match _path_rules.stage_of(_snapshot.wear.get(tile, 0)):
		PathRules.Stage.TRODDEN:
			cost = _cost_trodden
		PathRules.Stage.PATH:
			cost = _cost_path
	var mask: TravelMask = _masks.get(Chunk.world_to_chunk(tile))
	if mask != null and mask.is_trampled(Chunk.local_pos(tile), _day):
		cost += _cost_object
	return cost


## Takes the masks of the chunks in `missing` that `masks` has made (and asks for the others), and
## returns whether all of them are there. Main thread only, and not while a search runs on the view.
func provide(masks: TravelMasks) -> bool:
	for coords in missing.keys():
		var mask := masks.mask_of(coords)
		if mask != null:
			_masks[coords] = mask
			missing.erase(coords)
	return missing.is_empty()


## Gives the view the masks that are made for the chunks of the way from `start` to `goal` and a
## margin round it, and asks for none: a search that finds them there does not stop to wait for
## each one in turn. Main thread only, and not while a search runs on the view.
func prefetch(masks: TravelMasks, start: Vector2i, goal: Vector2i) -> void:
	var from := Chunk.world_to_chunk(start)
	var to := Chunk.world_to_chunk(goal)
	var low := Vector2i(mini(from.x, to.x), mini(from.y, to.y)) - Vector2i.ONE * PREFETCH_MARGIN
	var high := Vector2i(maxi(from.x, to.x), maxi(from.y, to.y)) + Vector2i.ONE * PREFETCH_MARGIN
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var coords := Vector2i(x, y)
			var mask := masks.made_mask(coords)
			if mask != null:
				_masks[coords] = mask
