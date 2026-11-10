class_name NightUpkeep
extends SimulationSystem
## What a night does to everything the player changed in a world, in unloaded chunks too: the
## soil dries and rain wets it, crops live through the day that ended (in the weather of their
## tile), cut reeds grow back by it, damage heals, picked bushes bear again, saplings grow up,
## stumps rot away, dug clay spots recover and desire paths grow back. Only edits change like
## this (a hit, a tilling, a planting or a step makes one), so they are all in the world's edits
## (or, for the wear of desire paths, in its own small table beside them).

var _world: World
var _weather: Weather
## Gives the tiles that a sapling does not grow into a tree on: it waits a day.
var _occupied_tiles: Callable


func _init(world: World, weather: Weather, occupied_tiles: Callable) -> void:
	_world = world
	_weather = weather
	_occupied_tiles = occupied_tiles


func advance(_minutes: int, clock: GameClock) -> void:
	if is_day_end(clock):
		pass_night()


## Lets the night pass over the world, which works from the weather of `clock.day - 1`.
func pass_night() -> void:
	var occupied_tiles: Array = _occupied_tiles.call()
	_dry_and_wet_soil()
	_world.recover_clay_spots()
	_world.regrow_paths()
	var yesterday := _world.clock.day - 1
	for object in _world.edited_objects():
		var has_changed := false
		if object.is_crop():
			var day := _weather.day_summary(object.pos, yesterday)
			has_changed = CropLife.live_through_day(object, day, _world.moisture_at(object.pos))
		elif ReedLife.is_reeds(object):
			var day := _weather.day_summary(object.pos, yesterday)
			has_changed = ReedLife.live_through_day(object, day)
		else:
			has_changed = object.pass_night()
		if has_changed:
			_world.change_object(object)
		if object.is_mature():
			var next := object.matured()
			if not (next.blocks_walking() and occupied_tiles.has(next.pos)):
				_world.replace_object(object, next)
		elif object.has_rotted():
			var sapling := object.rotted(_world.clock.day)
			if sapling == null:
				_world.take_off(object)
			else:
				_world.replace_object(object, sapling)


## Rain wets the tilled soil and the day dries it, as the weather of the day that ended says.
func _dry_and_wet_soil() -> void:
	var rules := CropRules.default_rules()
	for pos in _world.tilled_tiles():
		var day := _weather.day_summary(pos, _world.clock.day - 1)
		var drying := (
			rules.farming("drying_base")
			+ rules.farming("drying_per_degree") * maxf(day.mean_temperature, 0.0)
			+ rules.farming("drying_per_sun_hour") * day.sunlight_hours
			+ rules.farming("drying_per_wind") * day.max_wind_speed
		)
		_world.set_moisture(
			pos, _world.moisture_at(pos) + rules.farming("rain_wets") * day.rain_hours - drying
		)
