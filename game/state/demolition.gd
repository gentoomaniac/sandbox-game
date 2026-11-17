class_name Demolition
extends RefCounted
## Taking a building down: what it gives back, why it may not be, and the taking down itself.
## Keeps nothing: every function is given the game, and tells it what was done (see GameState
## `report`). What the hammer does with the player's own things is Builder's.

## What is said of a thing of the village that the player may not take down or up.
const THE_VILLAGES := "That is the village's."


## What taking a building down gives, item id to count: half of what it cost, rounded down
## (nothing with the cost cheat on, which built it for nothing).
static func refund_of(state: GameState, building: Building) -> Dictionary:
	var refund := {}
	if state.cheats.is_cost_off:
		return refund
	var costs: Dictionary = building.type_data()["costs"]
	for item: StringName in costs:
		if costs[item] / 2 > 0:
			refund[item] = costs[item] / 2
	return refund


## Why a building can't be taken down now, or "" if it can: it is the village's, the player is
## inside, or something the player put in it is still there (a thing they placed, or what a chest or
## station holds, also a millstone the house came with).
## The furniture the house came with (the default's or a villager's own room's), empty, goes
## with it.
static func why_not(state: GameState, building: Building) -> String:
	if state.world.is_village_building(building):
		return THE_VILLAGES
	if state.is_inside():
		return "You can't take a house down from inside."
	if building.interior == null:
		return ""
	var own_rooms: Array[Interior] = []
	var own_maps: Array[String] = [BuildingTypes.TYPES[building.type]["interior_map"]]
	own_maps.append_array(state.npcs.villagers.home_interiors(building.type))
	for map_path: String in own_maps:
		own_rooms.append(InteriorLoader.load_interior(map_path))
	var tool_use := ToolUse.new(state)
	for object in building.interior.objects():
		var holds_items := not tool_use.items_held_by(object).is_empty()
		# What has no drops came with the house; only a process station (the windmill's millstone)
		# can hold what the player put in.
		if not object.type_data().has("drops"):
			if holds_items and StationRules.default_rules().grid_slots_of(object.type) > 0:
				return "Take out what you put in it first."
			continue
		var is_own := own_rooms.any(
			func(room: Interior) -> bool:
				var own := room.object_at(object.pos)
				return own != null and own.type == object.type
		)
		if not is_own or holds_items:
			return "Take out what you put in it first."
	return ""


## Takes a building down: half its materials lie in front of its door. Not while `why_not` has a
## reason. A player whose home bed was in it has the camp's sleeping bag for home again (if the bag
## is gone they wake standing on its spot, as with any missing bed). Returns whether it was taken
## down.
static func take_down(state: GameState, building: Building) -> bool:
	if why_not(state, building) != "":
		return false
	var world := state.world
	if state.player.home_map == building.interior:
		state.player.home_map = world
		state.player.home_bed = CampSite.sleeping_bag_of_seed(world.world_seed)
	var refund := refund_of(state, building)
	world.remove_building(building)
	state.homes.building_gone(building)
	world.drop_items(building.door_tile() + Vector2i.DOWN, refund)
	state.report(ActionOutcome.DEMOLISH, building.origin, building.type, refund)
	return true
