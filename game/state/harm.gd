class_name Harm
extends RefCounted
## What the player takes from, breaks of and does to the villagers against their will
## (design/villagers/relationships.md, "What moves friendship"): stealing (from a chest, a field or
## a nest that is a villager's), damage (cutting a Knick, breaking a fence) and rudeness (walking
## through a villager). Each is written down as a deed (stole, damaged, rude: see DeedLog
## `record_harm`, so the village hears of it) and costs friendship, by the points of FriendshipRules
## `harm_points`, with the villagers who see it and only with them: a harm nobody sees costs
## nothing, the owner included.
##
## Whose things are whose: no plots. A thing on the village's land is the villager's whose house is
## nearest (within `owner_reach_tiles`), a thing inside a house the first of those who live there's.
## What the player makes on their own land is nobody's.

var _npcs: Npcs
var _homes: Households
var _clock: GameClock
var _deeds: DeedLog
## Gives the world, which a loaded game replaces.
var _world: Callable
## The day each villager was last pushed through, so that one walk is one harm.
var _pushed_on_day := {}


func _init(
	npcs: Npcs, homes: Households, clock: GameClock, deeds: DeedLog, world: Callable
) -> void:
	_npcs = npcs
	_homes = homes
	_clock = clock
	_deeds = deeds
	_world = world


## The kind of harm that a finished action is, or "" for one that is none: what is cut or taken
## down of a line across the land (a Knick, a fence, a wall), and what is taken from a crop, a
## nest or a chest.
static func kind_of(outcome: ActionOutcome) -> StringName:
	match outcome.kind:
		ActionOutcome.BREAK, ActionOutcome.TAKE_DOWN:
			var object_data: Dictionary = WorldObjectTypes.TYPES.get(outcome.object, {})
			var is_line: bool = object_data.has("connects") and not object_data.has("way")
			return GossipRules.DAMAGED if is_line else &""
		ActionOutcome.HARVEST, ActionOutcome.COLLECT, ActionOutcome.TAKE_FROM_CHEST:
			return GossipRules.STOLE
	return &""


## The villager whose thing is at `tile` of `map`, or null if it is nobody's.
func owner_of(map: GameMap, tile: Vector2i) -> Npc:
	var world: World = _world.call()
	if map is World:
		return _owner_on_village_land(world, tile)
	for building in world.buildings():
		if building.interior == map:
			var residents := _homes.residents_of(building)
			return null if residents.is_empty() else residents[0]
	return null


## Writes down and charges a finished action that is a harm to somebody's thing, if somebody saw.
func record(outcome: ActionOutcome) -> void:
	var kind := kind_of(outcome)
	if kind == &"":
		return
	var owner := owner_of(outcome.map, outcome.tile)
	if owner == null:
		return
	var witnesses := _witnesses(outcome.map, Vector2(outcome.tile) + Vector2(0.5, 0.5))
	_charge(kind, owner, witnesses)


## The player stands at `feet` out in the world: a villager they stand in is pushed through, which
## is rude, once a day for each (a villager keeps out of their way beyond `push_tiles`).
func check_pushing(feet: Vector2) -> void:
	var reach := FriendshipRules.default_rules().push_tiles()
	for npc in _npcs.all():
		var is_in_the_way := npc.inside == null and npc.position.distance_to(feet) <= reach
		if is_in_the_way and _pushed_on_day.get(npc, 0) != _clock.day:
			_pushed_on_day[npc] = _clock.day
			var witnesses := _witnesses(null, feet)
			if not witnesses.has(npc):
				witnesses.append(npc)
			_charge(GossipRules.RUDE, npc, witnesses)


func _owner_on_village_land(world: World, tile: Vector2i) -> Npc:
	if not world.is_village_land(tile):
		return null
	var owner: Npc
	var nearest := INF
	var reach := FriendshipRules.default_rules().owner_reach_tiles()
	for npc in _npcs.all():
		var distance := npc.anchor.distance_to(Vector2(tile) + Vector2(0.5, 0.5))
		if npc.house != null and distance <= reach and distance < nearest:
			owner = npc
			nearest = distance
	return owner


## Who sees a harm at `spot`: outdoors the villagers in sight of it, indoors (`map` is the
## interior) those who are in that house.
func _witnesses(map: GameMap, spot: Vector2) -> Array[Npc]:
	if map == null or map is World:
		return _deeds.witnesses_at(spot)
	var witnesses: Array[Npc] = []
	for npc in _npcs.all():
		if npc.inside != null and npc.inside.interior == map:
			witnesses.append(npc)
	return witnesses


## Writes the deed down for `owner`'s house and takes friendship from each witness.
func _charge(kind: StringName, owner: Npc, witnesses: Array[Npc]) -> void:
	if witnesses.is_empty():
		return
	_deeds.record_harm(kind, owner, witnesses)
	var friendship := FriendshipRules.default_rules()
	for npc in witnesses:
		npc.change_friendship(
			friendship.harm_points(kind), _clock.day, friendship, GossipRules.default_rules()
		)
