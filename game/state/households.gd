class_name Households
extends RefCounted
## Who lives where. A villager's house is a building (`Npc.house`), saved with them; the house
## holds a household, as many as its type has `residents`: the couple and their children (see
## `Npc.is_household_with`), so a house of one household is never shared with strangers. While
## a villager has a house their anchor is the yard in front of its door. Where they work is
## `Npc.workplace`. GameState owns it. The player gives a house with the hammer's menu and the
## console's `home` and `work` (see HomeCommands); the villagers of data/villagers.cfg find
## the house and the workplace their sheet names when they come into the world (`settle`).

var _npcs: Npcs


func _init(npcs: Npcs) -> void:
	_npcs = npcs


## The villagers who live in `house`.
func residents_of(house: Building) -> Array[Npc]:
	var residents: Array[Npc] = []
	for npc in _npcs.all():
		if npc.house == house:
			residents.append(npc)
	return residents


## Why `npc` can't live in `house`, or "" if they can: it is no house, it is theirs already, it
## is full, or another household lives there.
func why_not_live_in(npc: Npc, house: Building) -> String:
	var capacity: int = BuildingTypes.TYPES[house.type]["residents"]
	if capacity == 0:
		return "%s is no house." % house.type_data()["name"]
	if npc.house == house:
		return "%s lives there already." % npc.name
	var others := residents_of(house)
	if others.size() >= capacity:
		return "There is no room: %d live there." % others.size()
	if not others.is_empty() and not others.any(npc.is_household_with):
		return "Only one household lives in a house."
	return ""


## Makes `house` the home of `npc` (they leave their old one) and its yard their anchor. Returns
## why they can't, or "".
func move_in(npc: Npc, house: Building) -> String:
	var reason := why_not_live_in(npc, house)
	if reason == "":
		npc.house = house
		npc.anchor = house.yard()
	return reason


## They have no house. Their anchor stays where it was.
func move_out(npc: Npc) -> void:
	npc.house = null


## A building is gone: nobody lives or works in it any more.
func building_gone(building: Building) -> void:
	for npc in _npcs.all():
		if npc.house == building:
			move_out(npc)
		if npc.workplace != null and npc.workplace.building == building:
			npc.workplace = null


## The villagers within the menu's reach of `building`, the nearest first and no more than the
## menu lists (see `give_reach` and `give_list_size` of data/npcs.cfg).
func near(building: Building) -> Array[Npc]:
	var reach := _npcs.rules.behaviour("give_reach")
	var found := _npcs.all().filter(
		func(npc: Npc) -> bool: return npc.position.distance_to(building.centre()) <= reach
	)
	found.sort_custom(
		func(first: Npc, second: Npc) -> bool:
			return (
				first.position.distance_squared_to(building.centre())
				< second.position.distance_squared_to(building.centre())
			)
	)
	var listed: Array[Npc] = []
	listed.assign(found.slice(0, int(_npcs.rules.behaviour("give_list_size"))))
	return listed


## Gives the villager of data/villagers.cfg who just came into the world the house and the
## workplace their sheet names: a house where family of theirs lives, else the nearest one of
## the type with room, and the nearest building of the workplace's type, within `home_search`
## tiles. Where none stands they have none (and a spot has no place until it is given).
func settle(npc: Npc, world: World) -> void:
	var sheet := _npcs.villagers.villager(npc.id)
	var search := _npcs.rules.behaviour("home_search")
	var house_type := StringName(sheet.get(VillagerRules.HOME_BUILDING_KEY, ""))
	if house_type != &"":
		var house := _house_of_family(npc, house_type)
		if house == null:
			house = _nearest(npc, house_type, world, search, _has_room_for.bind(npc))
		if house != null:
			move_in(npc, house)
	var workplace_type := StringName(sheet.get(VillagerRules.WORKPLACE_BUILDING_KEY, ""))
	if workplace_type != &"":
		var workplace := _nearest(
			npc, workplace_type, world, search, func(_b: Building) -> bool: return true
		)
		if workplace != null:
			npc.workplace = Workplace.of_building(workplace)


## The house of the type where a household member of `npc` lives, if they can join.
func _house_of_family(npc: Npc, house_type: StringName) -> Building:
	for other in _npcs.all():
		var house := other.house
		if (
			house != null
			and house.type == house_type
			and npc.is_household_with(other)
			and why_not_live_in(npc, house) == ""
		):
			return house
	return null


func _has_room_for(house: Building, npc: Npc) -> bool:
	return why_not_live_in(npc, house) == ""


## The building of a type nearest to `npc` within `search` tiles that `is_fit` accepts, or null.
func _nearest(
	npc: Npc, building_type: StringName, world: World, search: float, is_fit: Callable
) -> Building:
	var nearest: Building
	var nearest_distance := search
	for building in world.buildings():
		var distance := building.centre().distance_to(npc.position)
		if (
			building.type == building_type
			and distance <= nearest_distance
			and is_fit.call(building)
		):
			nearest = building
			nearest_distance = distance
	return nearest
