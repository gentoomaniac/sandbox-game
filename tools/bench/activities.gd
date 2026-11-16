extends SceneTree
## Times the minute tick of the villagers' days (ActivityUpkeep, #7) with 155 villagers who have a
## house, on a Sunday morning (day 7, 09:45: the worst time, with a church to look for and a field
## and a wild spot for the others), and prints the milliseconds of the whole simulation's minute
## and of the activities' share of it. No make target, it needs no save and writes nothing:
## godot --headless --path . -s tools/bench/activities.gd

const VILLAGERS := 155
const MINUTES := 60
const SUNDAY := 7
const SEED := 7


func _init() -> void:
	var state := GameFactory.new_game(SEED)
	var around := state.player.tile()
	var houses: Array[Building] = []
	for y in range(-14, 15, 7):
		for x in range(-14, 15, 7):
			var house := state.world.place_building(BuildingTypes.KATE, around + Vector2i(x, y))
			if house != null:
				houses.append(house)
	state.world.place_building(BuildingTypes.CHURCH, around + Vector2i(24, -12))
	for index in 20:
		var tile := around + Vector2i(index - 10, 20)
		state.world.remove_object(tile)
		state.world.set_terrain(tile, Tile.Terrain.SOIL)
	assert(not houses.is_empty(), "no room for a house")
	for index in VILLAGERS:
		var npc := Npc.create(index, state.player.position, state.npcs.rules)
		npc.house = houses[index % houses.size()]
		npc.anchor = npc.house.yard()
		npc.position = npc.anchor
		state.npcs.add(npc)
	state.clock.day = SUNDAY
	state.clock.set_time(9, 45)
	var total_usec := 0
	var activities_usec := 0
	for _minute in MINUTES:
		var started := Time.get_ticks_usec()
		state.simulation.advance(1)
		total_usec += Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		state.activities.advance(1, state.clock)
		activities_usec += Time.get_ticks_usec() - started
	print("%d villagers with houses, %d minutes from Sunday 09:45" % [VILLAGERS, MINUTES])
	print("whole minute tick: %.3f ms (activities included)" % [total_usec / 1000.0 / MINUTES])
	print("activities' tick again with nothing new to do: %.3f ms" % [activities_usec / 1000.0 / MINUTES])
	quit()
