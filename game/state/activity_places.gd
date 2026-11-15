class_name ActivityPlaces
extends RefCounted
## Where an activity is done for one villager: a target of data/activities.cfg (home, workplace,
## field, church, meeting, friend, wild) as a spot of the world, found when it is asked for, so
## the answer follows what the player has built and tilled. `NOWHERE` is the answer when the
## villager has no such place, and the activity is not offered to them then.

const NOWHERE := Vector2.INF
## A wild spot is looked for this many times before there is none: it is a meadow tile at a
## distance from home between WILD_NEAREST_TILES and the `search_tiles` of the rules.
const WILD_TRIES := 24
const WILD_NEAREST_TILES := 8.0

var _world: World
var _npcs: Npcs
var _rules: ActivityRules


func _init(world: World, npcs: Npcs, rules := ActivityRules.default_rules()) -> void:
	_world = world
	_npcs = npcs
	_rules = rules


## The spot where `npc` does an activity with `target` on game day `day`: the middle of a tile.
## The same day gives the same spot for the same villager, and another day another one (a friend,
## a wild spot).
func spot_of(npc: Npc, target: String, day: int) -> Vector2:
	var spot := NOWHERE
	match target:
		"home":
			spot = NOWHERE if npc.house == null else npc.house.yard()
		"workplace":
			spot = spot_of(npc, "home", day) if npc.workplace == null else npc.workplace.spot()
		"field":
			spot = _field_of(npc)
		"church":
			spot = _church_yard_near(npc, _rules.search_tiles(target))
		"meeting":
			spot = _meeting_spot_near(npc, _rules.search_tiles(target))
		"friend":
			spot = _friend_yard_of(npc, day)
		"wild":
			spot = _wild_spot_of(npc, day)
		_:
			assert(false, "Not a target: %s" % target)
	return spot


## The building with an inside that `spot` is the yard of (the spot of a target with a door), or
## null: where a villager who is at the spot goes in.
func building_at_yard(spot: Vector2) -> Building:
	if spot == NOWHERE:
		return null
	var building := _world.building_at(Vector2i(spot.floor()) + Vector2i.UP)
	var is_door_there := building != null and building.yard() == spot and building.has_inside()
	return building if is_door_there else null


## The nearest tilled tile or field of the village within `search_tiles` of their home; with none,
## a workplace that is a spot (the fields have no building); with none, nowhere.
func _field_of(npc: Npc) -> Vector2:
	var home := _home_point(npc)
	var nearest := NOWHERE
	var nearest_distance := _rules.search_tiles("field")
	var tiles := _world.tilled_tiles()
	if _world.village != null:
		tiles.append_array(_world.village.field_spots)
	for tile in tiles:
		var centre := Vector2(tile) + Vector2(0.5, 0.5)
		if centre.distance_to(home) <= nearest_distance:
			nearest = centre
			nearest_distance = centre.distance_to(home)
	if nearest == NOWHERE and npc.workplace != null and npc.workplace.building == null:
		return npc.workplace.spot()
	return nearest


## The meeting spot of the village if it is within `search` of their home; else, where the world has
## no village, the yard of the church.
func _meeting_spot_near(npc: Npc, search: float) -> Vector2:
	if _world.village == null:
		return _church_yard_near(npc, search)
	var spot := Vector2(_world.village.meeting_spot) + Vector2(0.5, 0.5)
	return spot if spot.distance_to(_home_point(npc)) <= search else NOWHERE


func _church_yard_near(npc: Npc, search: float) -> Vector2:
	var home := _home_point(npc)
	var nearest := NOWHERE
	var nearest_distance := search
	for building in _world.buildings():
		if (
			building.type == BuildingTypes.CHURCH
			and building.yard().distance_to(home) <= nearest_distance
		):
			nearest = building.yard()
			nearest_distance = building.yard().distance_to(home)
	return nearest


## The yard of the house of one of their `people` who has one within `search_tiles` of their home,
## which one picked from the day and their name.
func _friend_yard_of(npc: Npc, day: int) -> Vector2:
	var home := _home_point(npc)
	var yards: Array[Vector2] = []
	for friend_id: String in npc.people:
		var friend := _npcs.find(friend_id)
		if (
			friend != null
			and friend.house != null
			and friend.house.yard().distance_to(home) <= _rules.search_tiles("friend")
		):
			yards.append(friend.house.yard())
	return NOWHERE if yards.is_empty() else yards[posmod(hash([npc.name, day]), yards.size())]


## A meadow tile that can be stood on, picked from the day and the villager's name: the same all
## day, and another tomorrow. Only tiles of loaded chunks are known, so a villager far from the
## player has none.
func _wild_spot_of(npc: Npc, day: int) -> Vector2:
	var home := _home_point(npc)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([npc.name, day, "wild"])
	for _try in WILD_TRIES:
		var distance := rng.randf_range(WILD_NEAREST_TILES, _rules.search_tiles("wild"))
		var tile := Vector2i((home + Vector2.from_angle(rng.randf() * TAU) * distance).floor())
		if _is_meadow(tile):
			return Vector2(tile) + Vector2(0.5, 0.5)
	return NOWHERE


func _is_meadow(tile: Vector2i) -> bool:
	var ground := _world.tile_at(tile)
	return (
		ground != null
		and ground.terrain == Tile.Terrain.GRASS
		and _world.object_at(tile) == null
		and _world.is_walkable(tile)
	)


## What distances are measured from: the yard of their house, or where they stand without one.
func _home_point(npc: Npc) -> Vector2:
	return npc.position if npc.house == null else npc.house.yard()
