class_name CropRaids
extends SimulationSystem
## The crows' raids on the crops: where the crow flocks are, and what each hour does to the crops
## near them (rules in data/crows.cfg, see CropRaidRules). The animals themselves are in the view,
## which tells this where its flocks stand (`add_flock`, `move_flock`, `remove_flock`).
##
## Every hour each flock that is not near the player may raid: it tries a few of the living crops
## within its reach that nothing guards (see `is_guarded`), and a crop loses a whole plant (a
## seed or a sprout) or a produce item (see CropLife `eaten`), by the chance of its growth stage.
## Caps per day keep a field from being stripped. A flock raids only the crops of loaded chunks,
## and flocks only stand near the player, so crops in unloaded chunks are never raided. The hours
## of a skip of time pass like those of play, for the flocks standing then. The dice are seeded by
## the world and the hour. Only the crops are saved (their `eaten`): flocks and the day's tally are
## not.

## Tells whether a crop tile is guarded from the crows: takes a tile, returns a bool. A scarecrow
## (task 226) sets it; unset, nothing is guarded.
var is_guarded := Callable()
## What the crows ate today: whole plants and produce items.
var plants_eaten_today := 0
var items_eaten_today := 0

var _world: World
## Where the player stands, in tiles (Vector2.INF when away): takes nothing.
var _player_feet: Callable
var _rules: CropRaidRules
## {flock id: tile it stands on}
var _flocks := {}
var _next_flock_id := 1
## The day the tally above is of.
var _tally_day := 0


func _init(world: World, player_feet: Callable, rules := CropRaidRules.default_rules()) -> void:
	_world = world
	_player_feet = player_feet
	_rules = rules


func advance(_minutes: int, clock: GameClock) -> void:
	if is_hour_end(clock):
		var ended_hour_start := clock.total_minutes() - GameClock.MINUTES_PER_HOUR
		raid_hour(ended_hour_start / GameClock.MINUTES_PER_HOUR)


## A flock settles on a tile. Returns its id.
func add_flock(tile: Vector2i) -> int:
	_flocks[_next_flock_id] = tile
	_next_flock_id += 1
	return _next_flock_id - 1


func move_flock(flock_id: int, tile: Vector2i) -> void:
	_flocks[flock_id] = tile


func remove_flock(flock_id: int) -> void:
	_flocks.erase(flock_id)


## Takes every flock away. Returns how many there were.
func clear_flocks() -> int:
	var count := _flocks.size()
	_flocks.clear()
	return count


## The tiles the flocks stand on.
func flock_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	tiles.assign(_flocks.values())
	return tiles


## Lets the hour `hour` (counted from the start of day 1) pass over the flocks: each one that has
## no player near raids with the chance of the hour. `is_forced` is for the console: every flock
## raids, with the player standing by.
func raid_hour(hour: int, is_forced := false) -> void:
	var day := hour / CropLife.HOURS_PER_DAY + 1
	if day != _tally_day:
		_tally_day = day
		plants_eaten_today = 0
		items_eaten_today = 0
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([_world.world_seed, hour])
	var player_feet: Vector2 = _player_feet.call()
	for flock_id: int in _flocks:
		var tile: Vector2i = _flocks[flock_id]
		var is_player_near := (
			_tile_centre(tile).distance_to(player_feet) <= _rules.value("player_tiles")
		)
		if is_forced or (not is_player_near and dice.randf() < _rules.value("hour_chance")):
			_raid(tile, dice, is_forced)


## How many times likelier a crow flock is to appear at a tile because of the fresh sowing around
## it: 1 for none, up to `sown_boost_max`.
func appearing_boost(tile: Vector2i) -> float:
	var radius := int(_rules.value("sown_radius_tiles"))
	var sown := 0
	for y in range(tile.y - radius, tile.y + radius + 1):
		for x in range(tile.x - radius, tile.x + radius + 1):
			var object := _world.object_at(Vector2i(x, y))
			if object != null and object.is_crop() and CropLife.stage(object) == 0:
				sown += 1
	return minf(1.0 + _rules.value("sown_boost_per_crop") * sown, max_appearing_boost())


## The most `appearing_boost` gives.
func max_appearing_boost() -> float:
	return _rules.value("sown_boost_max")


## What the console `crows` shows: the flocks, and what the crows ate today.
func describe() -> Array[String]:
	var lines: Array[String] = []
	for flock_id: int in _flocks:
		var tile: Vector2i = _flocks[flock_id]
		lines.append(
			(
				"Flock %d at %d, %d: %d crops in reach, player %s"
				% [flock_id, tile.x, tile.y, _crops_in_reach(tile).size(), _distance_text(tile)]
			)
		)
	if lines.is_empty():
		lines.append("No crow flocks")
	(
		lines
		. append(
			(
				"Today the crows ate %d of %d plants and %d of %d items"
				% [
					plants_eaten_today,
					_rules.value("max_plants_per_day"),
					items_eaten_today,
					_rules.value("max_items_per_day"),
				]
			)
		)
	)
	return lines


## A raid: some of the crops in reach of a flock lose something, each by the chance of its growth
## stage (a forced raid takes every crop it tries).
func _raid(tile: Vector2i, dice: RandomNumberGenerator, is_forced: bool) -> void:
	var crops := _crops_in_reach(tile)
	for _try in int(_rules.value("crops_per_raid")):
		if crops.is_empty():
			return
		var crop: WorldObject = crops.pop_at(dice.randi_range(0, crops.size() - 1))
		if is_forced or dice.randf() < _rules.stage_chance(CropLife.stage(crop)):
			_eat_from(crop)


## The living crops within reach of a tile that are not guarded.
func _crops_in_reach(tile: Vector2i) -> Array[WorldObject]:
	var reach := int(_rules.value("reach_tiles"))
	var crops: Array[WorldObject] = []
	for y in range(tile.y - reach, tile.y + reach + 1):
		for x in range(tile.x - reach, tile.x + reach + 1):
			var object := _world.object_at(Vector2i(x, y))
			if object != null and object.is_crop() and not CropLife.is_dead(object):
				if not _is_guarded(object.pos):
					crops.append(object)
	return crops


## The crows eat a seed or a sprout whole, or produce off a grown crop, within the caps of the day.
func _eat_from(crop: WorldObject) -> void:
	if CropLife.stage(crop) <= int(_rules.value("whole_up_to_stage")):
		if plants_eaten_today < _rules.value("max_plants_per_day"):
			plants_eaten_today += 1
			_world.remove_object(crop.pos)
	elif CropLife.has_yield_to_eat(crop) and items_eaten_today < _rules.value("max_items_per_day"):
		items_eaten_today += 1
		CropLife.eat(crop, 1)
		_world.change_object(crop)


func _is_guarded(tile: Vector2i) -> bool:
	return is_guarded.is_valid() and is_guarded.call(tile)


func _tile_centre(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func _distance_text(tile: Vector2i) -> String:
	var distance := _tile_centre(tile).distance_to(_player_feet.call())
	return "away" if is_inf(distance) else "%.0f tiles off" % distance
