class_name ReedLife
extends RefCounted
## What cut reeds do: they gather growth from the weather of every day and stand again once they
## have enough (see `regrow_growth` and the needs in data/crops.cfg, [reeds]). Reeds stand in water,
## so unlike a crop they need no soil moisture, and they have no bad days: a stand cut in autumn
## grows nothing while the days are too cold or too dark, and so is back only in spring.

## The state of a cut stand: the growth points it has gathered since it was cut.
const REGROWTH := "regrowth"


## Whether the object is a reed stand: wild reeds regrow with the weather.
static func is_reeds(object: WorldObject) -> bool:
	return object.type_data().has("regrow_growth")


## Lets a cut stand live through a day of this weather. Returns whether it stands again now.
static func live_through_day(reeds: WorldObject, day: WeatherDay) -> bool:
	if not reeds.is_picked():
		return false
	var needs := reeds.type_data()
	if day.sunlight_hours >= needs["sunlight_min"]:
		reeds.state[REGROWTH] = float(reeds.state[REGROWTH]) + CropLife.weather_score(needs, day)
	if float(reeds.state[REGROWTH]) < needs["regrow_growth"] - CropLife.GROWTH_EPSILON:
		return false
	reeds.state.erase(REGROWTH)
	return true
