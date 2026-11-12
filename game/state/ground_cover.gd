class_name GroundCover
extends RefCounted
## What lies on the ground of a tile: fallen leaves, frost and snow, each a share of the tile's
## art pixels from 0 to 1. This is the rule of the ground shader, kept here for the game logic
## (footsteps, flowers under snow) and to pin the shader to it in tests; gameplay never depends
## on how the ground is drawn.
##
## Each tile has four numbers, the `Channels` (what the view hands the shader as one texel per
## tile, so they are rounded to 8 bits here too): how many leaves, how much snow and how much of
## the thaw it catches, and how sheltered it is from frost. The numbers of the moment
## (`set_weather`) say how much leaf litter, snow cover, thaw and frost there are. A pixel shows
## the cover when its threshold in the ground's noise texture is below the share, so a share of
## 0.3 means 30 % of the pixels, organically spread.
## The numbers are in the sections [cover] and [litter] of data/seasons.cfg.

## What drops leaves in autumn: the broadleaved trees and the hedge.
const LEAFY: Array[StringName] = [
	WorldObjectTypes.OAK,
	WorldObjectTypes.BEECH,
	WorldObjectTypes.BIRCH,
	WorldObjectTypes.ALDER,
	WorldObjectTypes.WILLOW,
	WorldObjectTypes.KNICK,
]
## What shelters the ground under it: every tree and the hedge.
const CROWNED: Array[StringName] = [
	WorldObjectTypes.OAK,
	WorldObjectTypes.BEECH,
	WorldObjectTypes.BIRCH,
	WorldObjectTypes.ALDER,
	WorldObjectTypes.WILLOW,
	WorldObjectTypes.KNICK,
	WorldObjectTypes.SPRUCE,
	WorldObjectTypes.PINE,
]
## Where the wind comes from: a fixed westerly, so the lee of a building is to its east.
const LEE_DIRECTION := Vector2i.RIGHT
## Texels of the view's cover texture hold 8 bits per channel.
const LEVELS := 255.0


## What a tile catches, each 0 to 1 and rounded to 8 bits.
class Channels:
	extends RefCounted
	var leaves := 0.0
	var snow := 0.0
	var melt := 0.0
	var frost_shelter := 0.0

	func as_color() -> Color:
		return Color(leaves, snow, melt, frost_shelter)


var _world: World
var _litter := 0.0
var _snow_cover := 0.0
var _thaw := 0.0
var _frost := 0.0
## The numbers of [cover] in data/seasons.cfg, read once: they are asked for per tile.
var _crown_radius := 0.0
var _leaf_open := 0.0
var _leaf_field := 0.0
var _leaf_path := 0.0
var _snow_under_crown := 0.0
var _snow_lee := 0.0
var _snow_path := 0.0
var _melt_open := 0.0
var _melt_path := 0.0
var _melt_under_crown := 0.0
var _thaw_gain := 0.0
var _frost_under_crown := 0.0
var _lee_reach := 0


func _init(world: World, rules := SeasonRules.default_rules()) -> void:
	_world = world
	_crown_radius = rules.value("cover", "crown_radius")
	_leaf_open = rules.value("cover", "leaf_open")
	_leaf_field = rules.value("cover", "leaf_field")
	_leaf_path = rules.value("cover", "leaf_path")
	_snow_under_crown = rules.value("cover", "snow_under_crown")
	_snow_lee = rules.value("cover", "snow_lee")
	_snow_path = rules.value("cover", "snow_path")
	_melt_open = rules.value("cover", "melt_open")
	_melt_path = rules.value("cover", "melt_path")
	_melt_under_crown = rules.value("cover", "melt_under_crown")
	_thaw_gain = rules.value("cover", "thaw_gain")
	_frost_under_crown = rules.value("cover", "frost_under_crown")
	_lee_reach = int(rules.value("cover", "lee_reach"))


## The weather of the moment: the leaf litter (SeasonBlend.litter), the snow cover, the thaw
## (SnowCover.thaw_at) and the frost (SnowCover.frost_at), each 0 to 1.
func set_weather(litter: float, snow_cover: float, thaw: float, frost: float) -> void:
	_litter = litter
	_snow_cover = snow_cover
	_thaw = thaw
	_frost = frost


## The share of the tile's pixels with leaves.
func leaves_at(tile: Vector2i) -> float:
	return clampf(_litter * channels_at(tile).leaves, 0.0, 1.0)


## The share of the tile's pixels with frost.
func frost_at(tile: Vector2i) -> float:
	return clampf(_frost * (1.0 - channels_at(tile).frost_shelter), 0.0, 1.0)


## The share of the tile's pixels with snow: the cover it catches, less what the thaw takes.
func snow_at(tile: Vector2i) -> float:
	return _snow_with(tile, _snow_cover, _thaw)


## Whether snow lies on most of the tile (what footsteps and flowers ask).
func is_snowed(tile: Vector2i) -> bool:
	return snow_at(tile) >= 0.5


## Whether snow would lie on most of the tile with this snow cover and thaw instead of the weather
## of the moment (what the animals ask about another time).
func is_snowed_with(tile: Vector2i, snow_cover: float, thaw: float) -> bool:
	return _snow_with(tile, snow_cover, thaw) >= 0.5


## The channels of a tile: nothing lies where it catches nothing (water, tidal mud, rooms), and
## there the frost shelter is complete.
func channels_at(tile: Vector2i) -> Channels:
	var terrain_tile := _world.tile_at(tile)
	if terrain_tile == null:
		return _channels_of(Tile.Terrain.WATER, false, 0.0, 0.0, 0.0)
	return _channels_of(
		terrain_tile.terrain,
		_world.wear_stage(tile) == PathRules.Stage.PATH,
		_crown_at(tile, LEAFY),
		_crown_at(tile, CROWNED),
		_lee_at(tile)
	)


func _snow_with(tile: Vector2i, snow_cover: float, thaw: float) -> float:
	var channels := channels_at(tile)
	return clampf(snow_cover * channels.snow - thaw * channels.melt * _thaw_gain, 0.0, 1.0)


## How far (in tiles) a tree or a building changes the channels of the tiles around it: the
## crowns and the lee reach this far.
func reach() -> int:
	return maxi(ceili(_crown_radius), _lee_reach)


## The channels of the tiles of a loaded chunk and of `margin` tiles around it (at most `reach()`),
## as colours (see Channels.as_color), row by row from the top left of the square: the same as
## `channels_at` for each, but in one pass: the crowns and the lees are spread from the trees and
## buildings around the chunk, not searched for around every tile. The tiles of chunks that are
## not loaded come out as nothing lies there.
func chunk_channels(coords: Vector2i, margin := 0) -> PackedColorArray:
	assert(margin <= reach(), "the crowns and the lees are only spread this far")
	var size := Chunk.CHUNK_SIZE
	var side := size + 2 * margin
	var origin := Chunk.to_world(coords, Vector2i.ZERO) - Vector2i(margin, margin)
	var leafy_crowns := PackedFloat32Array()
	var crowns := PackedFloat32Array()
	var lees := PackedFloat32Array()
	for array in [leafy_crowns, crowns, lees]:
		array.resize(side * side)
	for neighbour in 9:
		var chunk := _world.chunk_at(coords + Vector2i(neighbour % 3 - 1, neighbour / 3 - 1))
		if chunk == null:
			continue
		for object in chunk.objects():
			if object.type not in CROWNED or _world.is_dormant(object):
				continue
			for tile in object.tiles():
				_spread_crown(crowns, tile - origin, side)
				if object.type in LEAFY:
					_spread_crown(leafy_crowns, tile - origin, side)
	for building in _world.buildings():
		for tile in building.tiles():
			_spread_lee(lees, tile - origin, side)
	var colours := PackedColorArray()
	colours.resize(side * side)
	for index in side * side:
		var tile := origin + Vector2i(index % side, index / side)
		var terrain_tile := _world.tile_at(tile)
		if terrain_tile != null:
			colours[index] = (
				_channels_of(
					terrain_tile.terrain,
					_world.wear_stage(tile) == PathRules.Stage.PATH,
					leafy_crowns[index],
					crowns[index],
					lees[index]
				)
				. as_color()
			)
		else:
			colours[index] = _channels_of(Tile.Terrain.WATER, false, 0.0, 0.0, 0.0).as_color()
	return colours


## What a tile of `terrain` catches, with the crowns over it (see `_crown_at`) and its lee.
func _channels_of(
	terrain: Tile.Terrain, is_path: bool, leafy_crown: float, crown: float, lee: float
) -> Channels:
	var channels := Channels.new()
	if not _is_covered(terrain):
		channels.frost_shelter = 1.0
		return channels
	var leaves := lerpf(_leaf_open, 1.0, leafy_crown)
	if terrain == Tile.Terrain.SOIL:
		leaves *= _leaf_field
	if is_path:
		leaves *= _leaf_path

	var snow := 1.0 - _snow_under_crown * crown
	snow *= 1.0 - _snow_lee * lee
	if is_path:
		snow *= _snow_path

	var melt: float = _melt_path if is_path else _melt_open
	melt *= 1.0 - (1.0 - _melt_under_crown) * crown

	channels.leaves = _rounded(leaves)
	channels.snow = _rounded(snow)
	channels.melt = _rounded(melt)
	channels.frost_shelter = _rounded(_frost_under_crown * crown)
	return channels


## Raises the crown over the tiles around `centre` (in the square `side` tiles across that
## `crowns` holds, row by row) to what a tree there casts on each.
func _spread_crown(crowns: PackedFloat32Array, centre: Vector2i, side: int) -> void:
	var radius: float = _crown_radius
	var reach := ceili(radius)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var local := centre + Vector2i(dx, dy)
			if local.x < 0 or local.y < 0 or local.x >= side or local.y >= side:
				continue
			var index := local.y * side + local.x
			crowns[index] = maxf(crowns[index], 1.0 - Vector2(dx, dy).length() / radius)


## Raises the lee over the tiles east of a building tile at `building_tile` (in the square `side`
## tiles across that `lees` holds, row by row) to what the building gives each (see `_lee_at`).
func _spread_lee(lees: PackedFloat32Array, building_tile: Vector2i, side: int) -> void:
	for distance in range(1, _lee_reach + 1):
		var local := building_tile + LEE_DIRECTION * distance
		if local.x >= 0 and local.y >= 0 and local.x < side and local.y < side:
			var index := local.y * side + local.x
			lees[index] = maxf(lees[index], 1.0 - float(distance - 1) / _lee_reach)


## Whether anything lies on the ground of this terrain: not on water, the tidal flats or in rooms.
func _is_covered(terrain: Tile.Terrain) -> bool:
	return (
		terrain
		not in [
			Tile.Terrain.WATER,
			Tile.Terrain.SEA,
			Tile.Terrain.MUD,
			Tile.Terrain.FLOOR,
			Tile.Terrain.CLAY_FLOOR,
			Tile.Terrain.WALL,
		]
	)


## How much of a tile lies under the crowns of the trees of `types`: 1 under a tree, less with
## every tile away from it, 0 at `crown_radius`.
func _crown_at(tile: Vector2i, types: Array[StringName]) -> float:
	var radius: float = _crown_radius
	var reach := ceili(radius)
	var crown := 0.0
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var object := _world.object_at(tile + Vector2i(dx, dy))
			if object == null or object.type not in types:
				continue
			crown = maxf(crown, 1.0 - Vector2(dx, dy).length() / radius)
	return clampf(crown, 0.0, 1.0)


## How much of a tile lies in the lee of a building: 1 right behind it, fading out to nothing
## beyond `lee_reach` tiles.
func _lee_at(tile: Vector2i) -> float:
	var reach := _lee_reach
	for distance in range(1, reach + 1):
		if _world.building_at(tile - LEE_DIRECTION * distance) != null:
			return 1.0 - float(distance - 1) / reach
	return 0.0


func _rounded(value: float) -> float:
	return roundf(clampf(value, 0.0, 1.0) * LEVELS) / LEVELS
