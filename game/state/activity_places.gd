class_name ActivityPlaces
extends RefCounted
## Where an activity is done for one villager: a target of data/activities.cfg (home, workplace,
## field, church, meeting, friend, wild, see ActivityTarget) as a spot of the world, found when it
## is asked for, so the answer follows what the player has built and tilled. `NOWHERE` is the
## answer when the villager has no such place, and the activity is not offered to them then. The
## kinds of target find their spots with what this knows of the world.

const NOWHERE := Vector2.INF

var world: World
var npcs: Npcs
var rules: ActivityRules


func _init(
	world_to_search: World, villagers: Npcs, activity_rules := ActivityRules.default_rules()
) -> void:
	world = world_to_search
	npcs = villagers
	rules = activity_rules


## The spot where `npc` does an activity with `target` on game day `day`: the middle of a tile.
## The same day gives the same spot for the same villager, and another day another one (a friend,
## a wild spot).
func spot_of(npc: Npc, target: String, day: int) -> Vector2:
	return rules.target(target).spot_of(npc, day, self)


## The building with an inside that `spot` is the yard of (the spot of a target with a door), or
## null: where a villager who is at the spot goes in.
func building_at_yard(spot: Vector2) -> Building:
	if spot == NOWHERE:
		return null
	var building := world.building_at(Vector2i(spot.floor()) + Vector2i.UP)
	var is_door_there := building != null and building.yard() == spot and building.has_inside()
	return building if is_door_there else null


## The yard of the church nearest to the villager's home, within `search` tiles of it.
func church_yard_near(npc: Npc, search: float) -> Vector2:
	var home := home_point(npc)
	var nearest := NOWHERE
	var nearest_distance := search
	for building in world.buildings():
		if (
			building.type == BuildingTypes.CHURCH
			and building.yard().distance_to(home) <= nearest_distance
		):
			nearest = building.yard()
			nearest_distance = building.yard().distance_to(home)
	return nearest


## What distances are measured from: the yard of their house, or where they stand without one.
func home_point(npc: Npc) -> Vector2:
	return npc.position if npc.house == null else npc.house.yard()
