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
var _rules: SeasonRules
var _litter := 0.0
var _snow_cover := 0.0
var _thaw := 0.0
var _frost := 0.0


func _init(world: World, rules := SeasonRules.default_rules()) -> void:
	_world = world
	_rules = rules


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
	var channels := channels_at(tile)
	var thawed: float = _thaw * channels.melt * _rules.value("cover", "thaw_gain")
	return clampf(_snow_cover * channels.snow - thawed, 0.0, 1.0)


## Whether snow lies on most of the tile (what footsteps and flowers ask).
func is_snowed(tile: Vector2i) -> bool:
	return snow_at(tile) >= 0.5


## The channels of a tile: nothing lies where it catches nothing (water, tidal mud, rooms), and
## there the frost shelter is complete.
func channels_at(tile: Vector2i) -> Channels:
	var channels := Channels.new()
	var terrain_tile := _world.tile_at(tile)
	if terrain_tile == null or not _is_covered(terrain_tile.terrain):
		channels.frost_shelter = 1.0
		return channels
	var leafy_crown := _crown_at(tile, LEAFY)
	var crown := _crown_at(tile, CROWNED)
	var is_path := _world.wear_stage(tile) == PathRules.Stage.PATH
	var is_field := terrain_tile.terrain == Tile.Terrain.SOIL

	var leaves := lerpf(_rules.value("cover", "leaf_open"), 1.0, leafy_crown)
	if is_field:
		leaves *= _rules.value("cover", "leaf_field")
	if is_path:
		leaves *= _rules.value("cover", "leaf_path")

	var snow := 1.0 - _rules.value("cover", "snow_under_crown") * crown
	snow *= 1.0 - _rules.value("cover", "snow_lee") * _lee_at(tile)
	if is_path:
		snow *= _rules.value("cover", "snow_path")

	var melt: float = _rules.value("cover", "melt_path" if is_path else "melt_open")
	melt *= 1.0 - (1.0 - _rules.value("cover", "melt_under_crown")) * crown

	channels.leaves = _rounded(leaves)
	channels.snow = _rounded(snow)
	channels.melt = _rounded(melt)
	channels.frost_shelter = _rounded(_rules.value("cover", "frost_under_crown") * crown)
	return channels


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
	var radius: float = _rules.value("cover", "crown_radius")
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
	var reach := int(_rules.value("cover", "lee_reach"))
	for distance in range(1, reach + 1):
		if _world.building_at(tile - LEE_DIRECTION * distance) != null:
			return 1.0 - float(distance - 1) / reach
	return 0.0


func _rounded(value: float) -> float:
	return roundf(clampf(value, 0.0, 1.0) * LEVELS) / LEVELS
