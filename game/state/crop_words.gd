class_name CropWords
extends RefCounted
## What crops tell the player, in plain words: what a crop likes (for the seed tooltips) and how
## a crop is doing (for the hover box). The numbers behind the words are in data/crops.cfg
## (CropRules), the thresholds between the words in its [farming] section.


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
