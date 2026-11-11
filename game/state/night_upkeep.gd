class_name NightUpkeep
extends SimulationSystem
## What a night does to everything the player changed in a world, in unloaded chunks too: cut
## reeds grow back by the day that ended (in the weather of their tile), damage heals, picked
## bushes bear again, saplings grow up, stumps rot away, dug clay spots recover, desire paths
## grow back and tilled soil that nobody tends grows over (see FallowSoil). The soil and the crops
## change every hour instead (see FarmingUpkeep). Only edits change like this (a hit, a tilling, a
## planting or a step makes one), so they are all in the world's edits (or, for the wear of desire
## paths and the fallow soil, in their own small tables beside them).

var _world: World
var _weather: Weather
var _occupied_tiles: Callable
## In a skip the nights are counted over the fallow soil, and it is seen to at the end (see
## `skipped_over_frames`): a skip of many nights can have tens of thousands of tiles whose days
## are up.
var _is_skipping := false


func _init(world: World, weather: Weather, occupied_tiles: Callable) -> void:
	_world = world
	_weather = weather
	_occupied_tiles = occupied_tiles


func advance(_minutes: int, clock: GameClock) -> void:
	if is_day_end(clock):
		pass_night()


## Lets the night pass over the world, which works from the weather of `clock.day - 1`. A sapling
## does not turn into a tree on a tile in `_occupied_tiles` (a Callable giving them): it waits a
## day.
func pass_night() -> void:
	var occupied_tiles: Array = _occupied_tiles.call()
	_world.recover_clay_spots()
	_world.regrow_paths()
	var yesterday := _world.clock.day - 1
	_world.fallow.count_night(yesterday)
	for object in _world.edited_objects():
		var has_changed := false
		if ReedLife.is_reeds(object):
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
	if not _is_skipping:
		_world.settle_fallow_soil()


func skip_begins(_minutes: int) -> void:
	_is_skipping = true


func skipped(_minutes: int, _clock: GameClock) -> void:
	_world.settle_fallow_soil()
	_is_skipping = false


func skipped_over_frames(_minutes: int, _clock: GameClock, next_frame: Callable) -> void:
	await _world.settle_fallow_soil_over_frames(next_frame)
	_is_skipping = false
