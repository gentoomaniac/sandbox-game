class_name Npcs
extends RefCounted
## The villagers of the world (Npc) and how they go about their day: each keeps near its anchor
## (the yard in front of the nearest building's door, or the nearest fireplace, when it came into
## the world), stands about and strolls by day, and stands still at night. The numbers are
## data/npcs.cfg (NpcRules). GameState owns it; Main moves them with `update` while the player is
## out in the world.
##
## The player walks through villagers, so none can shut the player in; a villager stops short
## of the player instead of walking into them.

## A villager came into the world.
signal added(npc: Npc)

## Spawned villagers stand this many tiles from the given point, at the least and at the most.
const SPAWN_DISTANCE := Vector2(1.5, 3.0)
const SPAWN_TRIES := 40
## A villager whose way is blocked turns by this many radians, by more each time and to either
## side (TURN_STEPS), before it gives up and stands.
const TURN := 0.6
const TURN_STEPS := [0, 1, -1, 2, -2, 3, -3]
## A long frame moves the villagers no further than this many seconds would.
const MAX_STEP_SECONDS := 0.05
## A stroll heads for a point this far into the anchor's circle, at the most, so it turns back
## before it reaches the edge.
const STROLL_REACH := 0.8

var rules := NpcRules.default_rules()
## The villagers written by hand (see `spawn_villager`).
var villagers := VillagerRules.default_rules()
var rng := RandomNumberGenerator.new()
var _sun: Sun
var _villager_step := PathRules.default_rules().villager_step()
var _npcs: Array[Npc] = []


## `sun` gives the times of sunrise and sunset that the villagers rest by.
func _init(sun: Sun) -> void:
	_sun = sun
	rng.randomize()


func all() -> Array[Npc]:
	return _npcs.duplicate()


func add(npc: Npc) -> void:
	_npcs.append(npc)
	added.emit(npc)


func to_array() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for npc in _npcs:
		data.append(npc.to_dict())
	return data


func load_array(data: Array) -> void:
	for npc_data: Dictionary in data:
		add(Npc.from_dict(npc_data))


## Puts up to `count` new villagers, each with a look, name and background of its own, where
## they can stand a few tiles around `near`, each anchored to what is nearest its spot. Returns
## how many found a place.
func spawn(count: int, near: Vector2, world: World) -> int:
	var placed := 0
	for _try in SPAWN_TRIES:
		if placed == count:
			break
		var feet := _spawn_spot(near)
		if PlayerState.can_stand_at(world, feet):
			_settle(Npc.create(rng.randi(), feet, rules), world)
			placed += 1
	return placed


## Puts the villager of data/villagers.cfg with that id where they can stand a few tiles around
## `near`, as `spawn` does. Returns them, or null if they found no place.
func spawn_villager(villager_id: String, near: Vector2, world: World) -> Npc:
	for _try in SPAWN_TRIES:
		var feet := _spawn_spot(near)
		if PlayerState.can_stand_at(world, feet):
			return _settle(Npc.create_villager(villager_id, feet, villagers), world)
	return null


## The villager of data/villagers.cfg with that id, or null if they are not in the world.
func find(villager_id: String) -> Npc:
	for npc in _npcs:
		if npc.id == villager_id:
			return npc
	return null


## The anchor of a villager that comes into the world at `feet`: the nearest of the yards in
## front of the buildings' doors and the fireplaces within `search` tiles, or `feet` itself.
static func anchor_near(feet: Vector2, world: World, search: float) -> Vector2:
	var points: Array[Vector2] = []
	for building in world.buildings():
		points.append(Vector2(building.door_tile() + Vector2i.DOWN) + Vector2(0.5, 0.5))
	var reach := ceili(search)
	var centre := Vector2i(feet.floor())
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var object := world.object_at(centre + Vector2i(x, y))
			if object != null and object.type == WorldObjectTypes.FIREPLACE:
				points.append(Vector2(object.pos) + Vector2(0.5, 0.5))
	var anchor := feet
	var nearest := search
	for point in points:
		if point.distance_to(feet) <= nearest:
			anchor = point
			nearest = point.distance_to(feet)
	return anchor


## Whether the villagers stand still for the night at a time of the game clock.
func is_rest_time(day: int, minute: int) -> bool:
	var rest := _sun.sunset(day) + rules.behaviour("rest_minutes_after_sunset")
	var up := _sun.sunrise(day) + rules.behaviour("up_minutes_after_sunrise")
	return minute >= rest or minute < up


## Lets `delta` seconds pass for every villager on `map` at the time of the game clock.
## Villagers stop short of the player's feet.
func update(delta: float, map: GameMap, player_feet: Vector2, clock: GameClock) -> void:
	if is_rest_time(clock.day, clock.minute_of_day):
		for npc in _npcs:
			npc.activity = Npc.Activity.IDLE
		return
	delta = minf(delta, MAX_STEP_SECONDS)
	for npc in _npcs:
		npc.seconds_left -= delta
		if npc.seconds_left <= 0.0:
			_start_next_activity(npc)
		elif npc.activity == Npc.Activity.WALK and not _walk(npc, delta, map, player_feet):
			_stand(npc)


## The player speaks to a villager: they turn to the player and stand a while.
func talk_to(npc: Npc, player_feet: Vector2) -> void:
	npc.turn_to(player_feet)
	npc.activity = Npc.Activity.IDLE
	npc.seconds_left = rules.behaviour("linger_seconds")


func _spawn_spot(near: Vector2) -> Vector2:
	var distance := rng.randf_range(SPAWN_DISTANCE.x, SPAWN_DISTANCE.y)
	return near + Vector2.from_angle(rng.randf() * TAU) * distance


## Anchors a villager who came into the world to what is nearest them, and adds them.
func _settle(npc: Npc, world: World) -> Npc:
	npc.anchor = anchor_near(npc.position, world, rules.behaviour("anchor_search"))
	npc.seconds_left = rules.pick_seconds("idle_seconds", rng)
	add(npc)
	return npc


func _start_next_activity(npc: Npc) -> void:
	if rng.randf() >= rules.behaviour("walk_chance"):
		_stand(npc)
		return
	var radius := rules.behaviour("anchor_radius") * STROLL_REACH
	var goal := npc.anchor + Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())
	if goal.is_equal_approx(npc.position):
		_stand(npc)
		return
	npc.activity = Npc.Activity.WALK
	npc.heading = (goal - npc.position).normalized()
	npc.seconds_left = rules.pick_seconds("walk_seconds", rng)


func _stand(npc: Npc) -> void:
	npc.activity = Npc.Activity.IDLE
	npc.seconds_left = rules.pick_seconds("idle_seconds", rng)


## Takes a step along the villager's heading, or as near to it as it can turn; returns whether
## it moved. Its body must stand on walkable tiles, it must keep within its anchor's circle (one
## outside it only steps back towards it), and it must not come closer to the player than
## `personal_space`. The tile it steps onto wears towards a desire path.
func _walk(npc: Npc, delta: float, map: GameMap, player_feet: Vector2) -> bool:
	var radius := rules.behaviour("anchor_radius")
	var personal_space := rules.behaviour("personal_space")
	var anchor_distance := npc.position.distance_to(npc.anchor)
	var player_distance := npc.position.distance_to(player_feet)
	for steps: int in TURN_STEPS:
		var way := npc.heading.rotated(steps * TURN)
		var feet := npc.position + way * rules.behaviour("walk_speed") * delta
		var new_anchor_distance := feet.distance_to(npc.anchor)
		if new_anchor_distance > radius and new_anchor_distance >= anchor_distance:
			continue
		var new_player_distance := feet.distance_to(player_feet)
		if new_player_distance < personal_space and new_player_distance < player_distance:
			return false
		if not _fits(npc, feet, map):
			continue
		var feet_tile := Vector2i(feet.floor())
		if feet_tile != npc.tile() and map is World and _villager_step > 0.0:
			(map as World).wear_tile(feet_tile, _villager_step)
		npc.position = feet
		npc.heading = way
		npc.facing = Npc.facing_of(way)
		return true
	return false


## Whether the villager's body fits on the map with its feet at `feet`. Asking the map is what
## costs (several microseconds a tile), so it is asked only when the body moves onto new tiles.
## The tiles found free stay trusted while the body stays on them, even if something is built
## there meanwhile: the villager steps off it as it moves on.
func _fits(npc: Npc, feet: Vector2, map: GameMap) -> bool:
	var body := PlayerState.body_tiles(feet)
	if body == npc.free_body_tiles:
		return true
	if not PlayerState.can_stand_at(map, feet):
		return false
	npc.free_body_tiles = body
	return true
