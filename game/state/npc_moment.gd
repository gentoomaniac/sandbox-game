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
## Whether a burning campfire is near (told only when no building is): one that is out is no
## "campfire" to be by.
var is_by_fire := false
## What the villagers know of the storm surge, as the facts for the prompt (see NpcPrompt
## `surge_text`): `running` (the sea is over the dykes), the time of `rises`, the `level` and the
## `low_dyke` height, in metres; empty when none is coming.
var surge := {}
## What the villager's shop is like, if they keep one (see ShopHours `fact`); empty otherwise.
var shop := {}


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
	moment.shop = ShopHours.fact(state, npc)
	moment.surge = _surge_facts(state)
	var centre := npc.tile()
	var tiles := ceili(reach)
	for y in range(-tiles, tiles + 1):
		for x in range(-tiles, tiles + 1):
			var object := state.world.object_at(centre + Vector2i(x, y))
			var is_burning := Campfire.is_campfire(object) and not Campfire.is_out(object)
			if is_burning and Vector2(x, y).length() <= reach:
				moment.is_by_fire = true
	return moment


## What is known of the surge that is coming or running (see `surge`).
static func _surge_facts(state: GameState) -> Dictionary:
	var surge := state.world.surge
	var now := state.clock.total_minutes()
	if not surge.is_stormy_at(now):
		return {}
	return {
		"running": not surge.is_expected_at(now),
		"rises": Sun.time_text(surge.start_minute() % GameClock.MINUTES_PER_DAY),
		"level": "%.1f" % surge.level,
		"low_dyke": "%.1f" % state.world.dykes.lowest_sea_dyke_height(state.world),
	}
