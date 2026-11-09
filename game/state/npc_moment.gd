class_name NpcMoment
extends RefCounted
## When and where a villager speaks, as the prompt tells it (see NpcPrompt): the time on the
## game clock, the sun's times of that day, the weather and what the villager stands by.

## The day and the minute of the day.
var clock := GameClock.new()
## Minutes of the day.
var sunrise := 0.0
var solar_noon := 0.0
var sunset := 0.0
var weather := WeatherSample.new()
## The name of the building the villager stands by, such as "Kate", or "" if none is near.
var building := ""
## Whether a fireplace is near (told only when no building is).
var is_by_fire := false


## The moment of the game now, for a villager in it. The weather is what the player sees (with a
## forced condition, see Console), as they stand together; buildings and fireplaces count within
## `reach` tiles of the villager.
static func of(state: GameState, npc: Npc, reach: float) -> NpcMoment:
	var moment := NpcMoment.new()
	moment.clock.day = state.clock.day
	moment.clock.minute_of_day = state.clock.minute_of_day
	moment.sunrise = state.sun.sunrise(state.clock.day)
	moment.solar_noon = state.sun.solar_noon(state.clock.day)
	moment.sunset = state.sun.sunset(state.clock.day)
	moment.weather = state.current_weather()
	var nearest := reach
	for building in state.world.buildings():
		var distance := Vector2(building.door_tile()).distance_to(npc.position)
		if distance <= nearest:
			nearest = distance
			moment.building = building.type_data()["name"]
	var centre := npc.tile()
	var tiles := ceili(reach)
	for y in range(-tiles, tiles + 1):
		for x in range(-tiles, tiles + 1):
			var object := state.world.object_at(centre + Vector2i(x, y))
			var is_fireplace := object != null and object.type == WorldObjectTypes.FIREPLACE
			if is_fireplace and Vector2(x, y).length() <= reach:
				moment.is_by_fire = true
	return moment
