class_name FallowSoil
extends RefCounted
## The tilled soil of a world that nobody tends: tilled soil with nothing on it comes up in weeds
## after `weedy_days` untended days, and is grass again after `grass_days` (see data/crops.cfg and
## World `settle_fallow_soil`). Hoeing, sowing and watering tend it, and so does anything that
## stands on it, a crop living or dead too: the days count anew from then.
##
## A world has tens of thousands of tilled tiles, so no night visits them all. The nights that
## count are numbered, each tile keeps the number of the night it was last tended at, and the
## tiles are filed by it, so that a night finds the few whose days are up at once. A night is
## counted (`count_night`) and then seen to (`settle_next_night`).

var weedy_days := int(CropRules.default_rules().farming("fallow_weedy_days"))
var grass_days := int(CropRules.default_rules().farming("fallow_grass_days"))
var rests_in_winter := CropRules.default_rules().farming("fallow_rests_in_winter") != 0.0
## The nights that counted since the world began.
var nights := 0
## How many of them have been seen to: a tile's days are counted up to here.
var settled_nights := 0
## Per tilled tile, the night it was last tended at.
var _tended_at: Dictionary[Vector2i, int] = {}
## The tilled tiles by the night they were last tended at, as the keys of a dictionary each.
var _tiles_by_night: Dictionary[int, Dictionary] = {}


## A tile was tilled or worked: its days count from the last night counted.
func tend(pos: Vector2i) -> void:
	forget(pos)
	_file(pos, nights)


## A tile that is soil no more.
func forget(pos: Vector2i) -> void:
	if not _tended_at.has(pos):
		return
	var night: int = _tended_at[pos]
	_tiles_by_night[night].erase(pos)
	if _tiles_by_night[night].is_empty():
		_tiles_by_night.erase(night)
	_tended_at.erase(pos)


## Whether weeds have come up on a tilled tile: its untended days are `weedy_days` or more.
func is_weedy(pos: Vector2i) -> bool:
	return _tended_at.has(pos) and settled_nights - _tended_at[pos] >= weedy_days


## Whether a tilled tile has been untended for `grass_days`: it is grass again.
func is_grown_over(pos: Vector2i) -> bool:
	return _tended_at.has(pos) and settled_nights - _tended_at[pos] >= grass_days


## Counts the night after a day (as GameClock.day), unless it is a winter's and they rest.
func count_night(day: int) -> void:
	if not rests_in_winter or GameClock.season_of(day) != GameClock.Season.WINTER:
		nights += 1


## Sees to the next night counted: returns the tiles whose days are up on it, those that come up
## in weeds and those that grow over. Whoever sees to them tends those that something stands on.
func settle_next_night() -> Array[Vector2i]:
	assert(settled_nights < nights, "No night to see to")
	settled_nights += 1
	var tiles: Array[Vector2i] = []
	for days: int in [weedy_days, grass_days]:
		tiles.append_array(_tiles_by_night.get(settled_nights - days, {}).keys())
	return tiles


## A copy of when each tile was last tended, for `array_of` (see World `snapshot`).
func snapshot() -> Dictionary:
	return _tended_at.duplicate()


## The save entries of a `snapshot`. Safe to call from a thread.
static func array_of(tended_at: Dictionary) -> Array[Array]:
	var entries: Array[Array] = []
	for pos: Vector2i in tended_at:
		entries.append(SaveCodec.vector_to_json(pos) + [tended_at[pos]])
	return entries


## Takes the saved nights and the entries of `array_of`. A save is taken with every night seen to.
func load_array(saved_nights: int, entries: Array) -> void:
	nights = saved_nights
	settled_nights = saved_nights
	for entry: Array in entries:
		_file(SaveCodec.vector_from_json(entry), int(entry[2]))


func _file(pos: Vector2i, night: int) -> void:
	_tended_at[pos] = night
	if not _tiles_by_night.has(night):
		_tiles_by_night[night] = {}
	_tiles_by_night[night][pos] = true
