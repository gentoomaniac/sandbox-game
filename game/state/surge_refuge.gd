class_name SurgeRefuge
extends SimulationSystem
## Where the villagers and the farm animals go when the sea is coming over the dykes (see
## design/world/storm-surge.md). From the warning to the end of the flood a villager who stands
## outdoors on land the water will cover walks to the nearest ground above it and stays there, their
## day held (ActivityUpkeep `hold`); when the water has drained they go back to their day. A farm
## animal in the water walks to the nearest dry ground and stands there.

## How far inland a villager looks for ground above the water, in tiles.
const REFUGE_REACH := 120
## Ground this much higher than the water is dry enough, in metres.
const REFUGE_MARGIN := 0.3
## How far an animal looks for dry ground through the water, in tiles walked.
const DRY_SEARCH_LIMIT := 2000
## How long an animal on its way to dry ground tries, in seconds.
const ANIMAL_WALK_SECONDS := 60.0

var _world: World
var _npcs: Npcs
var _livestock: Livestock
var _activities: ActivityUpkeep
var _sheltering: Array[Npc] = []
## The game minute before which an animal that found no dry ground is not led again, so the search
## does not repeat every tick.
var _next_search_minute: Dictionary[FarmAnimal, int] = {}


func _init(world: World, npcs: Npcs, livestock: Livestock, activities: ActivityUpkeep) -> void:
	_world = world
	_npcs = npcs
	_livestock = livestock
	_activities = activities


func advance(_minutes: int, clock: GameClock) -> void:
	var event := _world.surge
	var flood := _world.flood
	if not event.has_surge() and not flood.is_active():
		_release_villagers()
		return
	var level := maxf(event.level, flood.level if flood.is_active() else 0.0)
	for npc in _npcs.all():
		if not _sheltering.has(npc) and _is_in_danger(npc, level):
			_send_to_refuge(npc, level)
	if event.is_holding_at(clock.total_minutes()) or flood.is_active():
		for animal in _livestock.all():
			_lead_out_of_the_water(animal, clock.total_minutes())


# Whether a villager outdoors stands on land lower than the water will rise.
func _is_in_danger(npc: Npc, level: float) -> bool:
	if npc.inside != null:
		return false
	var tile := npc.tile()
	var tile_data := _world.tile_at(tile)
	return (
		tile_data != null
		and FloodState.FLOODABLE_TERRAINS.has(tile_data.terrain)
		and _world.elevation.at(tile, tile_data.terrain) < level
	)


# Sends a villager east (inland: the sea is in the west and the land rises eastwards) to the first
# tile of ground above the water, and holds their day.
func _send_to_refuge(npc: Npc, level: float) -> void:
	var tile := npc.tile()
	for step in range(1, REFUGE_REACH + 1):
		var candidate := tile + Vector2i(step, 0)
		var terrain := _world.tile_at(candidate)
		# The land beyond the loaded chunks is not known: the villager stays where they are.
		if terrain == null:
			return
		if _world.elevation.at(candidate, terrain.terrain) >= level + REFUGE_MARGIN:
			_sheltering.append(npc)
			_activities.hold(npc)
			_npcs.walk_to(npc, candidate, _world)
			return


func _release_villagers() -> void:
	for npc in _sheltering:
		_activities.release(npc)
	_sheltering.clear()


# Sends an animal standing in the water to the nearest dry tile, unless it is on its way to one.
func _lead_out_of_the_water(animal: FarmAnimal, now: int) -> void:
	if animal.is_ridden or animal.is_housed or animal.goal.is_finite():
		return
	if _world.flood.depth_at(animal.tile()) <= 0.0:
		return
	if _next_search_minute.get(animal, 0) > now:
		return
	var dry := _nearest_dry_tile(animal.tile())
	if dry == animal.tile():
		_next_search_minute[animal] = now + GameClock.MINUTES_PER_HOUR
		return
	animal.goal = Vector2(dry) + Vector2(0.5, 0.5)
	animal.goal_source = dry
	animal.goal_need = &""
	animal.activity = FarmAnimal.Activity.WALK
	animal.seconds_left = ANIMAL_WALK_SECONDS


# The nearest tile without water that an animal can stand on, found through the water tile by tile;
# the tile itself when there is none within DRY_SEARCH_LIMIT.
func _nearest_dry_tile(from: Vector2i) -> Vector2i:
	var seen: Dictionary[Vector2i, bool] = {from: true}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size() and head < DRY_SEARCH_LIMIT:
		var tile := queue[head]
		head += 1
		if _world.flood.depth_at(tile) <= 0.0 and _world.is_walkable_for_animals(tile):
			return tile
		for side in World.CONNECTION_SIDES:
			if not seen.has(tile + side):
				seen[tile + side] = true
				queue.append(tile + side)
	return from
