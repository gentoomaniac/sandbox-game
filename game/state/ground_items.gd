class_name GroundItems
extends RefCounted
## What lies on the ground of a map: the piles that were dropped by whatever the player
## harvested or let go of, until collected. The map owns it (`GameMap.ground_items`).
##
## It does not know the map, so the two never hold each other. The one thing it needs from
## the map, where a pile can lie, is given to `drop` per call.
##
## The piles are also kept by the chunk they lie in, so that what is near a point is found
## without looking at every pile. That index is not saved: `load_array` builds it again. A pile
## that moves goes through `move`, which keeps the index right.

## A pile of items was put on the ground, or taken off it.
signal added(ground_item: GroundItem)
signal removed(ground_item: GroundItem)
## What one `drop` call put on the ground, after `added` for each pile: the view lets them hop
## out of `source` (nothing about it is saved).
signal dropped(source: Vector2i, piles: Array[GroundItem])

## Dropped items lie on the free tiles within this many tiles of their source; the second
## range is for a source that has no free tile around it.
const SCATTER_RANGES := [1, 2]
## How long dropped piles wait before they can be pulled: the longest hop with its stagger,
## after a falling tree lands (about 1.3 s), with a little to spare.
const DROP_SETTLE_SECONDS := 1.4
## Where on its tile a dropped pile lies, as a fraction of the tile, so the piles of one drop
## don't line up on the tile centres.
const PILE_MARGIN := 0.25

var _piles: Array[GroundItem] = []
## The piles by the chunk they lie in, and the chunk each one is filed under.
var _piles_by_chunk: Dictionary[Vector2i, Array] = {}
var _chunk_of: Dictionary[GroundItem, Vector2i] = {}
## When each pile was laid (counting up), to give `near` the order of `all`.
var _serial_of: Dictionary[GroundItem, int] = {}
var _next_serial := 0


func all() -> Array[GroundItem]:
	return _piles.duplicate()


## The piles whose position is within `radius` tiles of `position`, oldest first.
func near(position: Vector2, radius: float) -> Array[GroundItem]:
	var low := Chunk.world_to_chunk(Vector2i((position - Vector2(radius, radius)).floor()))
	var high := Chunk.world_to_chunk(Vector2i((position + Vector2(radius, radius)).floor()))
	var found: Array[GroundItem] = []
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			for ground_item: GroundItem in _piles_by_chunk.get(Vector2i(x, y), []):
				if ground_item.position.distance_to(position) <= radius:
					found.append(ground_item)
	found.sort_custom(
		func(a: GroundItem, b: GroundItem) -> bool: return _serial_of[a] < _serial_of[b]
	)
	return found


## The piles in the chunk `centre` and the chunks within `chunk_radius` of it (a square).
func in_chunks_around(centre: Vector2i, chunk_radius: int) -> Array[GroundItem]:
	var found: Array[GroundItem] = []
	for y in range(centre.y - chunk_radius, centre.y + chunk_radius + 1):
		for x in range(centre.x - chunk_radius, centre.x + chunk_radius + 1):
			found.append_array(_piles_by_chunk.get(Vector2i(x, y), []))
	return found


## How many of an item lie on the ground, in all piles.
func count_of(item: StringName) -> int:
	var total := 0
	for ground_item in _piles:
		if ground_item.item == item:
			total += ground_item.count
	return total


## Lays a pile at an exact position (`drop` scatters instead).
func add(ground_item: GroundItem) -> void:
	_piles.append(ground_item)
	_file(ground_item, _next_serial)
	_next_serial += 1
	added.emit(ground_item)


## Takes a pile off the ground (it was collected).
func remove(ground_item: GroundItem) -> void:
	_piles.erase(ground_item)
	_unfile(ground_item)
	removed.emit(ground_item)


## Moves a pile to another position (it is pulled towards the player).
func move(ground_item: GroundItem, position: Vector2) -> void:
	var serial := _serial_of[ground_item]
	_unfile(ground_item)
	ground_item.position = position
	_file(ground_item, serial)


## Puts items (item id to count) on the ground around a tile: each kind is split into piles of
## about the same size over the tiles of `map` near `source` that can hold a pile, in an
## order that depends on the tile, the kind and the map's `pile_seed` only. Call it after the source
## was removed or replaced, so its own tile counts if it is free now. Returns the piles.
func drop(source: Vector2i, drops: Dictionary, map: GameMap) -> Array[GroundItem]:
	var kind_index := 0
	var dropped_piles: Array[GroundItem] = []
	for item: StringName in drops:
		var tiles := _scatter_tiles(source, kind_index, map)
		var total: int = drops[item]
		var piles := mini(total, tiles.size())
		for pile in piles:
			var count := total / piles + (1 if pile < total % piles else 0)
			var offset := Vector2(
				_hash_fraction(tiles[pile], 2 * kind_index, map.pile_seed()),
				_hash_fraction(tiles[pile], 2 * kind_index + 1, map.pile_seed())
			)
			var ground_item := GroundItem.new(item, count, Vector2(tiles[pile]) + offset)
			ground_item.settle_seconds = DROP_SETTLE_SECONDS
			add(ground_item)
			dropped_piles.append(ground_item)
		kind_index += 1
	dropped.emit(source, dropped_piles)
	return dropped_piles


func to_array() -> Array[Dictionary]:
	return GroundItems.array_of(snapshot())


## A copy of the piles, in the order they were laid, for `array_of` (see World `snapshot`): as
## packed arrays, which take far less time to fill than the save data does.
func snapshot() -> Dictionary:
	var items := PackedStringArray()
	var counts := PackedInt32Array()
	var positions := PackedVector2Array()
	for ground_item in _piles:
		items.append(ground_item.item)
		counts.append(ground_item.count)
		positions.append(ground_item.position)
	return {"items": items, "counts": counts, "positions": positions}


## The save data of a `snapshot`. Safe to call from a thread.
static func array_of(snapshot_data: Dictionary) -> Array[Dictionary]:
	var items: PackedStringArray = snapshot_data["items"]
	var counts: PackedInt32Array = snapshot_data["counts"]
	var positions: PackedVector2Array = snapshot_data["positions"]
	var data: Array[Dictionary] = []
	for index in items.size():
		(
			data
			. append(
				{
					"item": items[index],
					"count": counts[index],
					"position": SaveCodec.float_vector_to_json(positions[index]),
				}
			)
		)
	return data


func load_array(data: Array) -> void:
	for ground_item_data: Dictionary in data:
		var ground_item := GroundItem.from_dict(ground_item_data)
		_piles.append(ground_item)
		_file(ground_item, _next_serial)
		_next_serial += 1


func _file(ground_item: GroundItem, serial: int) -> void:
	var chunk := Chunk.world_to_chunk(Vector2i(ground_item.position.floor()))
	_chunk_of[ground_item] = chunk
	_serial_of[ground_item] = serial
	if not _piles_by_chunk.has(chunk):
		_piles_by_chunk[chunk] = []
	_piles_by_chunk[chunk].append(ground_item)


func _unfile(ground_item: GroundItem) -> void:
	assert(_chunk_of.has(ground_item), "Not a pile on the ground")
	var chunk := _chunk_of[ground_item]
	_chunk_of.erase(ground_item)
	_serial_of.erase(ground_item)
	_piles_by_chunk[chunk].erase(ground_item)
	if _piles_by_chunk[chunk].is_empty():
		_piles_by_chunk.erase(chunk)


## The free walkable tiles near `source`, in the order the piles of the `kind_index`th kind of
## a drop go to them. With none free, the source itself.
func _scatter_tiles(source: Vector2i, kind_index: int, map: GameMap) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for scatter_range: int in SCATTER_RANGES:
		for y in range(-scatter_range, scatter_range + 1):
			for x in range(-scatter_range, scatter_range + 1):
				if map.can_hold_pile(source + Vector2i(x, y)):
					tiles.append(source + Vector2i(x, y))
		if not tiles.is_empty():
			break
	if tiles.is_empty():
		return [source]
	var salt := PositionHash.of(source, kind_index)
	tiles.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return PositionHash.of(a, salt) < PositionHash.of(b, salt)
	)
	return tiles


## A value from PILE_MARGIN to 1 - PILE_MARGIN, always the same for the same tile and salt.
func _hash_fraction(tile: Vector2i, salt: int, seed_value: int) -> float:
	var fraction := float(PositionHash.of(tile, salt + seed_value)) / (PositionHash.MASK + 1)
	return PILE_MARGIN + fraction * (1.0 - 2.0 * PILE_MARGIN)
