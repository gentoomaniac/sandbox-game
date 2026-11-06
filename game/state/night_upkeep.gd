class_name NightUpkeep
extends RefCounted
## What a night does to everything the player changed in a world, in unloaded chunks too: the
## soil dries and rain wets it, crops live through the day that ended (in the weather of their
## tile), cut reeds grow back by it, damage heals, picked bushes bear again, saplings grow up,
## stumps rot away, dug clay spots recover and desire paths grow back. Only edits change like
## this (a hit, a tilling, a planting or a step makes one), so they are all in the world's edits
## (or, for the wear of desire paths, in its own small table beside them).


## Lets the night pass over `world`, which works from the weather of `clock.day - 1`. A sapling
## does not turn into a tree on a tile in `occupied_tiles`: it waits a day.
static func pass_night(world: World, occupied_tiles: Array[Vector2i], weather: Weather) -> void:
	_dry_and_wet_soil(world, weather)
	world.recover_clay_spots()
	world.regrow_paths()
	var yesterday := world.clock.day - 1
	for object in world.edited_objects():
		var has_changed := false
		if object.is_crop():
			var day := weather.day_summary(object.pos, yesterday)
			has_changed = CropLife.live_through_day(object, day, world.moisture_at(object.pos))
		elif ReedLife.is_reeds(object):
			var day := weather.day_summary(object.pos, yesterday)
			has_changed = ReedLife.live_through_day(object, day)
		else:
			has_changed = object.pass_night()
		if has_changed:
			world.change_object(object)
		if object.is_mature():
			var next := object.matured()
			if not (next.blocks_walking() and occupied_tiles.has(next.pos)):
				world.replace_object(object, next)
		elif object.has_rotted():
			var sapling := object.rotted(world.clock.day)
			if sapling == null:
				world.take_off(object)
			else:
				world.replace_object(object, sapling)


## Rain wets the tilled soil and the day dries it, as the weather of the day that ended says.
static func _dry_and_wet_soil(world: World, weather: Weather) -> void:
	var rules := CropRules.default_rules()
	for pos in world.tilled_tiles():
		var day := weather.day_summary(pos, world.clock.day - 1)
		var drying := (
			rules.farming("drying_base")
			+ rules.farming("drying_per_degree") * maxf(day.mean_temperature, 0.0)
			+ rules.farming("drying_per_sun_hour") * day.sunlight_hours
			+ rules.farming("drying_per_wind") * day.max_wind_speed
		)
		world.set_moisture(
			pos, world.moisture_at(pos) + rules.farming("rain_wets") * day.rain_hours - drying
		)
