class_name HomeCommands
extends RefCounted
## What the console's `home` and `work` do to a villager's house and workplace: show it, give the
## building (or a spot) the player is at, or free it. The words are "" (show), `here` and `none`.

## How far (in tiles) from a door's yard the player still is "at" that building.
const HERE_REACH := 4.0

var _state: GameState


func _init(state: GameState) -> void:
	_state = state


func home(npc: Npc, where: String) -> Array[String]:
	match where:
		"none":
			_state.homes.move_out(npc)
			return ["%s has no home now" % npc.name]
		"here":
			var house := _building_here()
			if house == null:
				return ["No building here: stand at a door, or inside"]
			var problem := _state.homes.move_in(npc, house)
			if problem != "":
				return [problem]
	if npc.house == null:
		return ["%s has no home" % npc.name]
	return ["%s lives in the %s (%s)" % [npc.name, _name_of(npc.house), npc.house.origin]]


func work(npc: Npc, where: String) -> Array[String]:
	match where:
		"none":
			npc.workplace = null
			return ["%s has no workplace now" % npc.name]
		"here":
			npc.workplace = _workplace_here(npc)
	if npc.workplace == null:
		return ["%s has no workplace" % npc.name]
	var place := npc.workplace
	var tile := place.building.origin if place.building != null else place.spot_tile
	var label := "the %s" % place.label() if place.building != null else place.label()
	return ["%s works at %s (%s)" % [npc.name, label, tile]]


## The building the player is inside, else the one whose door yard is nearest within HERE_REACH,
## or null.
func _building_here() -> Building:
	var nearest: Building
	var nearest_distance := HERE_REACH
	for building in _state.world.buildings():
		if _state.is_inside() and building.interior == _state.current_map:
			return building
		var distance := building.yard().distance_to(_state.player.position)
		if not _state.is_inside() and distance <= nearest_distance:
			nearest = building
			nearest_distance = distance
	return nearest


## The building here, else a spot where the player stands, named as the villager's sheet names
## the spot they work at, if it does.
func _workplace_here(npc: Npc) -> Workplace:
	var building := _building_here()
	if building != null:
		return Workplace.of_building(building)
	var tile := _state.player.tile()
	var villagers := _state.npcs.villagers
	var sheet := villagers.villager(npc.id) if villagers.has(npc.id) else {}
	return Workplace.of_spot(sheet.get(VillagerRules.WORKPLACE_SPOT_KEY, "a spot"), tile)


func _name_of(building: Building) -> String:
	return building.type_data()["name"]
