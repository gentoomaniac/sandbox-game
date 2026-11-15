class_name Households
extends RefCounted
## Who lives where. A villager's house is a building (`Npc.house`), saved with them; the house
## holds a household, as many as its type has `residents`: the couple and their children (see
## `Npc.is_household_with`), so a house of one household is never shared with strangers. While
## a villager has a house their anchor is the yard in front of its door. Where they work is
## `Npc.workplace`. GameState owns it. The player gives a house with the hammer's menu and the
## console's `home` and `work` (see HomeCommands); the villagers of data/villagers.cfg find
## the house and the workplace their sheet names when they come into the world (`settle`).
## A building someone lives in is a workplace only for those who live there (#69).

## A villager's house or workplace was given, taken or taken down: what the day has them do
## follows (see ActivityUpkeep).
signal changed(npc: Npc)

## The building the player is inside, or null: its room must not change under their feet.
var building_with_player: Building

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


## Why `npc` can't live in `house`, or "" if they can: it is no house, the player is inside it and
## their move-in would change its room, it is theirs already, it is full, another household
## lives there, or others who don't live there work there.
func why_not_live_in(npc: Npc, house: Building) -> String:
	var capacity: int = BuildingTypes.TYPES[house.type]["residents"]
	if capacity == 0:
		return "%s is no house." % house.type_data()["name"]
	var own_room := _own_interior_for(npc, house)
	if house == building_with_player and own_room != "" and house.can_be_furnished():
		return "Not while you are inside."
	if npc.house == house:
		return "%s lives there already." % npc.name
	var others := residents_of(house)
	if others.size() >= capacity:
		return "There is no room: %d live there." % others.size()
	if not others.is_empty() and not others.any(npc.is_household_with):
		return "Only one household lives in a house."
	return _why_others_work_there(npc, house)


## "Others work there" if villagers who don't live in `house` work there, besides `npc`, else "".
func _why_others_work_there(npc: Npc, house: Building) -> String:
	var outsiders := workers_of(house).filter(
		func(worker: Npc) -> bool: return worker != npc and worker.house != house
	)
	return "Others work there: %s." % _names(outsiders) if not outsiders.is_empty() else ""


## Why `npc` can't work in `building`, or "" if they can: others live there and they don't.
func why_not_work_in(npc: Npc, building: Building) -> String:
	if npc.house != building and not residents_of(building).is_empty():
		return "Only those who live in the %s work there." % building.type_data()["name"]
	return ""


## Makes `building` the workplace of `npc`. Returns why they can't, or "".
func give_work(npc: Npc, building: Building) -> String:
	var reason := why_not_work_in(npc, building)
	if reason == "":
		set_workplace(npc, Workplace.of_building(building))
	return reason


## Makes `workplace` (a building or a spot, or null for none) the workplace of `npc`.
func set_workplace(npc: Npc, workplace: Workplace) -> void:
	npc.workplace = workplace
	changed.emit(npc)


## Makes `house` the home of `npc` (they leave their old one) and its yard their anchor, and the
## inside of the map their sheet names, if any (see `Building.furnish_from`). Returns why they
## can't, or "".
func move_in(npc: Npc, house: Building) -> String:
	var reason := why_not_live_in(npc, house)
	if reason == "":
		_leave_house(npc)
		npc.house = house
		npc.anchor = house.yard()
		var own_room := _own_interior_for(npc, house)
		if own_room != "":
			house.furnish_from(own_room)
		changed.emit(npc)
	return reason


## The map the sheet of `npc` names for the inside of their home, if `house` is of the type the
## sheet names for it, else "".
func _own_interior_for(npc: Npc, house: Building) -> String:
	if not _npcs.villagers.has(npc.id):
		return ""
	var sheet := _npcs.villagers.villager(npc.id)
	if sheet.get(VillagerRules.HOME_BUILDING_KEY, "") != str(house.type):
		return ""
	return sheet.get(VillagerRules.HOME_INTERIOR_KEY, "")


## They have no house. Their anchor stays where it was. If they worked in it and others still live
## there, they work there no more.
func move_out(npc: Npc) -> void:
	_leave_house(npc)
	changed.emit(npc)


func _leave_house(npc: Npc) -> void:
	var old_house := npc.house
	npc.house = null
	if (
		old_house != null
		and npc.workplace != null
		and npc.workplace.building == old_house
		and not residents_of(old_house).is_empty()
	):
		npc.workplace = null


## A building is gone: nobody lives or works in it any more.
func building_gone(building: Building) -> void:
	for npc in _npcs.all():
		if npc.house == building:
			move_out(npc)
		if npc.workplace != null and npc.workplace.building == building:
			set_workplace(npc, null)


## Villagers who work in `building`.
func workers_of(building: Building) -> Array[Npc]:
	var workers: Array[Npc] = []
	for npc in _npcs.all():
		if npc.workplace != null and npc.workplace.building == building:
			workers.append(npc)
	return workers


## What the hover box over `building` says, a line each: its name, who lives there and how many
## of its places are taken (a house only), and who works there (if anybody does).
func occupants_text(building: Building) -> String:
	var lines: Array[String] = [building.type_data()["name"]]
	var capacity: int = BuildingTypes.TYPES[building.type]["residents"]
	if capacity > 0:
		var residents := residents_of(building)
		lines.append(
			(
				"Lives here: %s" % _names(residents)
				if not residents.is_empty()
				else "Nobody lives here"
			)
		)
		lines.append("%d of %d places taken" % [residents.size(), capacity])
	var workers := workers_of(building)
	if not workers.is_empty():
		lines.append("Works here: %s" % _names(workers))
	return "\n".join(lines)


func _names(npcs: Array[Npc]) -> String:
	return ", ".join(npcs.map(func(npc: Npc) -> String: return npc.name))


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


## What the hammer's menu offers on `building`, each `{text, npc, is_home}`: giving it as a home
## to the villagers near that may live in it, then as a workplace to the ones near who may work
## there and don't already.
func offers(building: Building) -> Array[Dictionary]:
	var listed: Array[Dictionary] = []
	var nearby := near(building)
	for npc in nearby:
		if why_not_live_in(npc, building) == "":
			var verb := "Give to %s" if npc.house == null else "Move %s in"
			listed.append({"text": verb % npc.name, "npc": npc, "is_home": true})
	for npc in nearby:
		var is_there := npc.workplace != null and npc.workplace.building == building
		if not is_there and why_not_work_in(npc, building) == "":
			listed.append({"text": "%s works here" % npc.name, "npc": npc, "is_home": false})
	return listed


## Does what an entry of `offers` says.
func accept(offer: Dictionary, building: Building) -> void:
	var npc: Npc = offer["npc"]
	if offer["is_home"]:
		move_in(npc, building)
	else:
		give_work(npc, building)


## Gives the villager of data/villagers.cfg who just came into the world the house and the
## workplace their sheet names: a house where family of theirs lives, else the nearest one of
## the type with room, and as the workplace their own house if it is of the workplace's type,
## else the nearest building of that type they may work in, within `home_search` tiles. Where
## none stands they have none (and a spot has no place until it is given).
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
		var workplace: Building = (
			npc.house if npc.house != null and npc.house.type == workplace_type else null
		)
		if workplace == null:
			workplace = _nearest(
				npc,
				workplace_type,
				world,
				search,
				func(building: Building) -> bool: return why_not_work_in(npc, building) == ""
			)
		if workplace != null:
			give_work(npc, workplace)


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
