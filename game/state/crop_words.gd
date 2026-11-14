class_name CropWords
extends RefCounted
## What crops tell the player, in plain words: what a crop likes (for the seed tooltips) and how
## a crop is doing (for the hover box). The numbers behind the words are in data/crops.cfg
## (CropRules), the thresholds between the words in its [farming] section.

## What a bad day does to a crop (see CropLife `troubles`), in words.
const TROUBLE_WORDS := {
	&"frost": "Frost is hurting it",
	&"drought": "Dry soil is hurting it",
	&"darkness": "Too little sun is hurting it",
	&"wind": "Wind is hurting it",
}


## The lines a seed's tooltip adds about its crop: the weather it likes, the water it needs, the
## wind it stands and about how many days it takes in good weather.
static func likes_lines(crop_id: StringName) -> Array[String]:
	var rules := CropRules.default_rules()
	var crop := rules.crop(crop_id)
	var weather := (
		"warm"
		if crop["temperature_best"] >= rules.farming("warm_from_best_temperature")
		else "cool"
	)
	var water := "middle"
	if crop["moisture_best"] <= rules.farming("water_low_up_to"):
		water = "low"
	elif crop["moisture_best"] >= rules.farming("water_high_from"):
		water = "high"
	var wind := "tender" if crop["wind_max"] < rules.farming("tender_below_wind") else "hardy"
	return [
		"Likes %s weather" % weather,
		"Water need: " + water,
		"Wind: " + wind,
		_days_line(crop),
	]


## "About 9 days in good weather", and for a crop that fruits again "then about 4 days again".
static func _days_line(crop: Dictionary) -> String:
	var stage_days: float = crop["growth_per_stage"]
	var stages_to_ripen := CropRules.STAGES - 1
	var line := "About %d days in good weather" % roundi(stage_days * stages_to_ripen)
	if crop["regrow_stage"] > 0:
		var stages_to_ripen_again: int = stages_to_ripen - crop["regrow_stage"]
		line += ", then about %d again" % roundi(stage_days * stages_to_ripen_again)
	return line


## How a crop is doing today, a line each: its name and state (growing, ripe, dead), when a ripe
## one withers, what hurts or slows it (the day's weather and the soil's moisture; the crop only
## knows the moisture, not the wet look of rain on the surface), how damaged it is, and the
## soil's moisture. `day` is the weather of the crop's day.
static func state_text(crop: WorldObject, day: WeatherDay, moisture: float) -> String:
	var crop_type := crop.type_data()
	if CropLife.is_dead(crop):
		return "%s, dead\nClear it with the hand or the hoe." % crop_type["name"]
	var lines: Array[String] = []
	if CropLife.is_ripe(crop):
		lines.append("%s, ripe" % crop_type["name"])
		lines.append(
			"Pick it: it will wither %s" % _withers_in(CropLife.days_until_withering(crop))
		)
	else:
		lines.append("%s, growing" % crop_type["name"])
	lines.append_array(_trouble_lines(crop, day, moisture))
	if CropLife.damage(crop) > 0.0:
		var bad_days_left := ceili((1.0 - CropLife.damage(crop)) / crop_type["damage_per_bad_day"])
		lines.append("Damaged: %d more bad days kill it" % bad_days_left)
	lines.append("Soil moisture %.2f, %s" % [moisture, _moisture_word(crop_type, moisture)])
	return "\n".join(lines)


## "tonight" or "in 3 days" (the days it has left, see CropLife `days_until_withering`).
static func _withers_in(days_left: int) -> String:
	return "tonight" if days_left == 1 else "in %d days" % days_left


## What hurts the crop today (a bad day), else what slows it (less than a good day's growth); a
## ripe crop grows no more, so nothing slows it.
static func _trouble_lines(crop: WorldObject, day: WeatherDay, moisture: float) -> Array[String]:
	var lines: Array[String] = []
	var troubles := CropLife.troubles(crop, day, moisture)
	for trouble in troubles:
		lines.append(TROUBLE_WORDS[trouble])
	if not troubles.is_empty() or CropLife.is_ripe(crop):
		return lines
	var crop_type := crop.type_data()
	var good_from: float = CropRules.default_rules().farming("good_day_score")
	if CropLife.warmth_score(crop_type, day.mean_temperature) < good_from:
		var is_cold: bool = day.mean_temperature < crop_type["temperature_best"]
		lines.append("Slowed by " + ("cold" if is_cold else "heat"))
	if CropLife.light_score(crop_type, day.sunlight_hours) < good_from:
		lines.append("Slowed by too little sun")
	if moisture / crop_type["moisture_best"] < good_from:
		lines.append("Slowed by dry soil")
	return lines


## How the soil's moisture stands to the crop's needs: below its minimum it is hurt.
static func _moisture_word(crop_type: Dictionary, moisture: float) -> String:
	if moisture < crop_type["moisture_min"]:
		return "too dry"
	if moisture < crop_type["moisture_best"]:
		return "a little dry"
	return "good"
