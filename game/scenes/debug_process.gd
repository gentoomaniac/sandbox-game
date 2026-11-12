class_name DebugProcess
extends RefCounted
## For screenshots (`--process=<kiln|oven>,<phase>`): a kiln or an oven beside the player, the
## inventory given what its recipes take and a few things they don't, a skill that leaves a
## recipe locked, and the grid in a phase: `empty`; `loaded`, a part load at the kiln and a load of
## berry tarts at the oven, which rules out the bread; `running`, three loads half done; `done`.

const PHASES: Array[String] = ["empty", "loaded", "running", "done"]
const CARRIED := {
	WorldObjectTypes.KILN:
	{
		ItemTypes.RAW_BRICK: 40,
		ItemTypes.LOGS: 20,
		ItemTypes.STONE: 15,
		ItemTypes.CLAY: 8,
		ItemTypes.BERRIES: 10,
	},
	WorldObjectTypes.OVEN:
	{
		ItemTypes.FLOUR: 20,
		ItemTypes.BERRIES: 40,
		&"strawberries": 8,
		ItemTypes.LOGS: 10,
		ItemTypes.STONE: 15,
	},
}
## The skill points of the player: a mason with the first bonus, a cook short of the feast cake.
const SKILLS := {
	WorldObjectTypes.KILN: [&"masonry", 55.0], WorldObjectTypes.OVEN: [&"cooking", 55.0]
}
## What a phase past `loaded` runs.
const RUNS := {WorldObjectTypes.KILN: &"bricks", WorldObjectTypes.OVEN: &"bread"}


## Puts the station on the tile right of the player, on the map they are on, and returns it as
## the window takes it.
static func create(state: GameState, station_type: StringName, phase: String) -> ProcessStation:
	var tile := state.player.tile() + Vector2i.RIGHT
	var object := WorldObject.new(station_type, tile)
	state.current_map.remove_object(tile)
	state.current_map.add_object(object)
	var station := ProcessStation.new(state, Crafting.new(state), object)
	var carried: Dictionary = CARRIED[station_type]
	for item: StringName in carried:
		state.player.inventory.add(item, carried[item])
	state.player.skills.set_points(SKILLS[station_type][0], SKILLS[station_type][1])
	if phase == "loaded" and station_type == WorldObjectTypes.KILN:
		object.storage.add(ItemTypes.RAW_BRICK, 12)
		object.storage.add(ItemTypes.LOGS, 3)
	elif phase == "loaded":
		station.fill(&"berry_tart", 1)
	elif phase != "empty":
		var recipe_id: StringName = RUNS[station_type]
		station.fill(recipe_id, 3)
		station.start()
		var minutes := roundi(station.crafting.rules.hours(recipe_id) * GameClock.MINUTES_PER_HOUR)
		state.simulation.advance(minutes if phase == "done" else minutes / 2)
	return station
