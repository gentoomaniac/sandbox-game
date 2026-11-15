class_name VillagePeople
extends RefCounted
## The villagers of data/villagers.cfg move into the village (design/world/wehlsbuell.md, section
## 10), once, when a new game has built it: each is spawned at the door of the building the plan
## says they live in, and takes the house and the workplace their sheet names (see
## Households `settle`), or the plan's where the sheet names none (the mill house, the spots).

## Tiles around a door that are loaded for the villagers to stand on.
const DOOR_REACH := 4


## Moves the villagers in and marks the village as populated. Returns why one could not come, or
## "". Does nothing in a world with no village, or one that was populated before.
static func move_in(state: GameState, site: VillageSite, plan: VillagePlan) -> String:
	var village := state.world.village
	if village == null or village.is_populated:
		return ""
	var generator := WorldGenerator.new(state.world.world_seed)
	var loaded: Array[Vector2i] = []
	var refusal := ""
	for entry in plan.buildings:
		var building := state.world.building_at(site.to_world(entry["origin"]))
		var around := Rect2i(Vector2i(building.yard().floor()), Vector2i.ONE).grow(DOOR_REACH)
		loaded.append_array(VillageBuilder.load_chunks(state.world, generator, around))
		for villager_id: String in entry["residents"]:
			var npc := state.npcs.spawn_villager(villager_id, building.yard(), state.world)
			if npc == null:
				refusal = "%s found no place at the door of %s" % [villager_id, entry["id"]]
				continue
			if npc.house != building:
				state.homes.move_in(npc, building)
			_give_the_spot_of_work(state, npc, site, plan)
	for coords in loaded:
		state.world.remove_chunk(coords)
	village.is_populated = true
	return refusal


## A villager whose sheet names a spot to work at (no building fits it) works at the plan's tile of
## it.
static func _give_the_spot_of_work(
	state: GameState, npc: Npc, site: VillageSite, plan: VillagePlan
) -> void:
	var spot_name: String = state.npcs.villagers.villager(npc.id).get(
		VillagerRules.WORKPLACE_SPOT_KEY, ""
	)
	if spot_name != "":
		var tile := site.to_world(plan.workplace_spots[spot_name])
		state.homes.set_workplace(npc, Workplace.of_spot(spot_name, tile))
