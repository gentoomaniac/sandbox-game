class_name GroundItems
extends RefCounted
## What lies on the ground of a world: the piles that were dropped by whatever the player
## harvested, until collected. The world owns it (`World.ground_items`).
##
## It does not know the world, so the two never hold each other. The one thing it needs from
## the world, where a pile can lie, is given to `drop` per call.

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


func all() -> Array[GroundItem]:
	return _piles.duplicate()


## The piles whose position is within `radius` tiles of `position`.
func near(position: Vector2, radius: float) -> Array[GroundItem]:
	return _piles.filter(
		func(ground_item: GroundItem) -> bool:
			return ground_item.position.distance_to(position) <= radius
	)


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
	added.emit(ground_item)


## Takes a pile off the ground (it was collected).
func remove(ground_item: GroundItem) -> void:
	_piles.erase(ground_item)
	removed.emit(ground_item)


## Puts items (item id to count) on the ground around a tile: each kind is split into piles of
## about the same size over the tiles of `world` near `source` that can be walked on, in an
## order that depends on the tile, the kind and the world's seed only. Call it after the source
## was removed or replaced, so its own tile counts if it is free now.
func drop(source: Vector2i, drops: Dictionary, world: World) -> void:
	var kind_index := 0
	var dropped_piles: Array[GroundItem] = []
	for item: StringName in drops:
		var tiles := _scatter_tiles(source, kind_index, world)
		var total: int = drops[item]
		var piles := mini(total, tiles.size())
		for pile in piles:
			var count := total / piles + (1 if pile < total % piles else 0)
			var offset := Vector2(
				_hash_fraction(tiles[pile], 2 * kind_index, world.world_seed),
				_hash_fraction(tiles[pile], 2 * kind_index + 1, world.world_seed)
			)
			var ground_item := GroundItem.new(item, count, Vector2(tiles[pile]) + offset)
			ground_item.settle_seconds = DROP_SETTLE_SECONDS
			add(ground_item)
			dropped_piles.append(ground_item)
		kind_index += 1
	dropped.emit(source, dropped_piles)


func to_array() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for ground_item in _piles:
		data.append(ground_item.to_dict())
	return data


func load_array(data: Array) -> void:
	for ground_item_data: Dictionary in data:
		_piles.append(GroundItem.from_dict(ground_item_data))


## The free walkable tiles near `source`, in the order the piles of the `kind_index`th kind of
## a drop go to them. With none free, the source itself.
func _scatter_tiles(source: Vector2i, kind_index: int, world: World) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for scatter_range: int in SCATTER_RANGES:
		for y in range(-scatter_range, scatter_range + 1):
			for x in range(-scatter_range, scatter_range + 1):
				if world.is_walkable(source + Vector2i(x, y)):
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
func _hash_fraction(tile: Vector2i, salt: int, world_seed: int) -> float:
	var fraction := float(PositionHash.of(tile, salt + world_seed)) / (PositionHash.MASK + 1)
	return PILE_MARGIN + fraction * (1.0 - 2.0 * PILE_MARGIN)
