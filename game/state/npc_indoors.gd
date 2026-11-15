class_name NpcIndoors
extends RefCounted
## Villagers going into buildings, being inside and coming out (see design/villagers/inside.md).
## Npcs owns one and calls it for the villagers who are going in or are in. A villager inside
## stands on a free tile of the room and, now and then, walks a few steps in a straight line until
## the time is up or something is in the way: no search, a room is small and nobody counts on where
## they go. Their `position` stays in the yard in front of the door (see `Npc.inside`).

## The numbers of data/npcs.cfg; Npcs hands on a change of them.
var rules: NpcRules
var _rng: RandomNumberGenerator


func _init(npc_rules: NpcRules, random: RandomNumberGenerator) -> void:
	rules = npc_rules
	_rng = random


## A villager standing in the yard in front of the door of `building` goes in: they walk onto the
## door tile (`update_entering`) and are inside from there; with `is_instant`, nobody sees it, and
## they are inside now. Nothing happens for one who is going in or is in it already.
func go_in(npc: Npc, building: Building, is_instant: bool) -> void:
	if npc.inside == building or npc.entering == building:
		return
	come_out(npc)
	npc.entering = building
	if is_instant:
		_finish_entering(npc)


## Takes a villager out of the building they are in or going into: they stand in the yard in front
## of its door, as if they had come out of it. Nothing happens for one who is outdoors.
func come_out(npc: Npc) -> void:
	var building := npc.inside if npc.inside != null else npc.entering
	npc.entering = null
	if npc.inside == null:
		return
	npc.inside = null
	npc.position = building.yard()
	npc.free_body_tiles = Rect2i()
	_stand(npc)


## Lets `delta` seconds pass for a villager going in: they walk onto the door tile, if `is_seen`,
## and are inside when they get there.
func update_entering(npc: Npc, delta: float, is_seen: bool) -> void:
	var door := Vector2(npc.entering.door_tile()) + Vector2(0.5, 0.5)
	var step := rules.behaviour("walk_speed") * delta
	if is_seen and npc.position.distance_to(door) > step:
		var way := (door - npc.position).normalized()
		npc.position += way * step
		npc.facing = Npc.facing_of(way)
		return
	_finish_entering(npc)


## Lets `delta` seconds pass for a villager inside `interior`. `is_resting`, and a villager who
## stands still by their day's order, stand.
func update(npc: Npc, delta: float, interior: Interior, is_resting: bool) -> void:
	if is_resting:
		npc.activity = Npc.Activity.IDLE
		return
	npc.seconds_left -= delta
	if npc.activity == Npc.Activity.WALK:
		var feet := npc.inside_position + npc.heading * rules.behaviour("walk_speed") * delta
		if Npcs.can_stand_at(interior, feet):
			npc.inside_position = feet
			npc.facing = Npc.facing_of(npc.heading)
		else:
			_stand(npc)
		if npc.seconds_left <= 0.0:
			_stand(npc)
	elif npc.seconds_left <= 0.0:
		if npc.is_staying_put or _rng.randf() >= rules.behaviour("walk_chance"):
			_stand(npc)
		else:
			npc.activity = Npc.Activity.WALK
			npc.heading = Vector2.from_angle(_rng.randf() * TAU)
			npc.seconds_left = rules.pick_seconds("walk_seconds", _rng)


## The villager going in is inside, on a free tile of the room.
func _finish_entering(npc: Npc) -> void:
	var building := npc.entering
	npc.entering = null
	npc.inside = building
	npc.position = building.yard()
	npc.inside_position = _free_spot(building.inside())
	_stand(npc)


## A free tile's middle of `interior`, where a villager who comes in stands: not the doormat and the
## tile inside it, where the player comes in. The middle of the room when it has no free tile.
func _free_spot(interior: Interior) -> Vector2:
	var spots: Array[Vector2] = []
	for y in interior.size.y:
		for x in interior.size.x:
			var tile := Vector2i(x, y)
			var spot := Vector2(tile) + Vector2(0.5, 0.5)
			if (
				tile != interior.exit_tile
				and tile != interior.entry_tile()
				and Npcs.can_stand_at(interior, spot)
			):
				spots.append(spot)
	return Vector2(interior.size) / 2.0 if spots.is_empty() else spots[_rng.randi() % spots.size()]


func _stand(npc: Npc) -> void:
	npc.activity = Npc.Activity.IDLE
	npc.seconds_left = rules.pick_seconds("idle_seconds", _rng)
