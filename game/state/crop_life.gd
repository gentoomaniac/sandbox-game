class_name CropLife
extends RefCounted
## What a crop (a WorldObject whose type has `growth_stages`) does over its life, as functions
## of the object. Its state has `growth`, the points gathered (a perfect day gives 1; each
## stage takes `growth_per_stage` of them), and `crop_damage`, from 0 to 1, where 1 is dead.
## Every night it lives through the day that ended: its weather and the moisture of its soil
## give a score, or trouble (see `troubles` and `live_through_day`). The numbers of each crop
## are in data/crops.cfg (see CropRules).

## Growth is a sum of fractions, so a crop that gathered exactly a stage's worth may be a hair
## short of it.
const GROWTH_EPSILON := 0.0001


static func growth(crop: WorldObject) -> float:
	return float(crop.state.get("growth", 0.0))


static func damage(crop: WorldObject) -> float:
	return float(crop.state.get("crop_damage", 0.0))


## The growth stage, 0 for a freshly planted crop, up to the last (ripe) one.
static func stage(crop: WorldObject) -> int:
	var crop_type := crop.type_data()
	var stages_grown := int(growth(crop) / crop_type["growth_per_stage"] + GROWTH_EPSILON)
	return mini(stages_grown, int(crop_type["growth_stages"]) - 1)


static func is_dead(crop: WorldObject) -> bool:
	return damage(crop) >= 1.0


static func is_ripe(crop: WorldObject) -> bool:
	return not is_dead(crop) and stage(crop) == crop.type_data()["growth_stages"] - 1


## Which picture of the crop's sheet it shows: the growth stage, or after the last one the dead
## stage.
static func look(crop: WorldObject) -> int:
	return crop.type_data()["growth_stages"] if is_dead(crop) else stage(crop)


## What harvesting a crop gives, item id to count: the yield, and one seed back.
static func harvest_of(crop: WorldObject) -> Dictionary:
	var crop_type := crop.type_data()
	return {crop_type["produce"]: crop_type["yield"], crop_type["seed"]: 1}


## Whether a crop stays in the ground after a harvest, to ripen again.
static func regrows(crop: WorldObject) -> bool:
	return crop.type_data()["regrow_stage"] > 0


## Takes a crop that regrows back to the growth stage it ripens again from.
static func regrow(crop: WorldObject) -> void:
	assert(regrows(crop), "Does not regrow: %s" % crop.type)
	crop.state["growth"] = crop.type_data()["regrow_stage"] * crop.type_data()["growth_per_stage"]


## What is wrong with a day for a crop, as a list of &"drought", &"darkness", &"frost" and
## &"wind". Any of them makes it a bad day.
static func troubles(crop: WorldObject, day: WeatherDay, moisture: float) -> Array[StringName]:
	var crop_type := crop.type_data()
	var found: Array[StringName] = []
	if moisture < crop_type["moisture_min"]:
		found.append(&"drought")
	if day.sunlight_hours < crop_type["sunlight_min"]:
		found.append(&"darkness")
	if day.min_temperature < crop_type["temperature_min"]:
		found.append(&"frost")
	if day.max_wind_speed > crop_type["wind_max"]:
		found.append(&"wind")
	return found


## How well a day met a crop's needs, from 0 to 1: the lowest of the scores for the day's mean
## temperature (none at the minimum and the maximum, full at the best), its hours of sun and the
## soil's moisture (full at their best, less in proportion).
static func score(crop: WorldObject, day: WeatherDay, moisture: float) -> float:
	var crop_type := crop.type_data()
	var warmth := 0.0
	var temperature := day.mean_temperature
	var coldest: float = crop_type["temperature_min"]
	var best: float = crop_type["temperature_best"]
	var hottest: float = crop_type["temperature_max"]
	if temperature > coldest and temperature < hottest:
		warmth = (
			(temperature - coldest) / (best - coldest)
			if temperature <= best
			else (hottest - temperature) / (hottest - best)
		)
	var light := clampf(day.sunlight_hours / crop_type["sunlight_best"], 0.0, 1.0)
	var water := clampf(moisture / crop_type["moisture_best"], 0.0, 1.0)
	return minf(warmth, minf(light, water))


## Lets a crop live through a day of this weather on soil of this moisture. A bad day (see
## `troubles`) does it damage and gives no growth; any other grows it by the day's score, and a
## good one (see CropRules `good_day_score`) also heals it. Returns whether its look changed.
static func live_through_day(crop: WorldObject, day: WeatherDay, moisture: float) -> bool:
	if is_dead(crop):
		return false
	var crop_type := crop.type_data()
	var look_before := look(crop)
	if not troubles(crop, day, moisture).is_empty():
		crop.state["crop_damage"] = minf(damage(crop) + crop_type["damage_per_bad_day"], 1.0)
		return look(crop) != look_before
	var day_score := score(crop, day, moisture)
	var ripe_growth: float = (crop_type["growth_stages"] - 1) * crop_type["growth_per_stage"]
	crop.state["growth"] = minf(growth(crop) + day_score, ripe_growth)
	if day_score >= CropRules.default_rules().farming("good_day_score"):
		crop.state["crop_damage"] = maxf(damage(crop) - crop_type["heal_per_good_day"], 0.0)
	return look(crop) != look_before


## What the console `crop` command shows: how a crop is doing and what it needs.
static func describe(crop: WorldObject) -> Array[String]:
	var crop_type := crop.type_data()
	var ripe_growth: float = (crop_type["growth_stages"] - 1) * crop_type["growth_per_stage"]
	var status := "dead" if is_dead(crop) else "stage %d" % (stage(crop) + 1)
	return [
		(
			"%s: %s, growth %.1f of %.1f, damage %.2f"
			% [crop_type["name"], status, growth(crop), ripe_growth, damage(crop)]
		),
		(
			"Warmth %.0f to %.0f °C (best %.0f), wind up to %.0f m/s"
			% [
				crop_type["temperature_min"],
				crop_type["temperature_max"],
				crop_type["temperature_best"],
				crop_type["wind_max"],
			]
		),
		(
			"Sun %.1f to %.1f h, moisture %.2f to %.2f"
			% [
				crop_type["sunlight_min"],
				crop_type["sunlight_best"],
				crop_type["moisture_min"],
				crop_type["moisture_best"],
			]
		),
	]


## Crops used to count days, one stage each: turns the days of a crop from an old save into
## growth.
static func upgrade_old_state(crop: WorldObject) -> void:
	if crop.is_crop() and crop.state.has("days_grown"):
		crop.state["growth"] = (
			float(crop.state["days_grown"]) * crop.type_data()["growth_per_stage"]
		)
		crop.state.erase("days_grown")
