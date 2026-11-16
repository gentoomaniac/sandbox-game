class_name Elevation
extends RefCounted
## How high the land lies, in metres over mean high water: the height the storm surge's flood is
## measured against (see design/world/storm-surge.md). A pure function of the world seed and the
## terrain, never saved. The numbers are in the `[surge]` section of data/landscape.cfg.

## Offsets the noise seed so it is independent of the generator's noises.
const SEED_OFFSET := 40
## What stays dry whatever the sea does: the floors and walls of the houses.
const NEVER_FLOODED := 100.0

## The `[surge]` key of the terrains with a height of their own. Water and the sea lie as low as
## the mud.
const BASE_KEYS := {
	Tile.Terrain.MUD: "mud",
	Tile.Terrain.WATER: "mud",
	Tile.Terrain.SEA: "mud",
	Tile.Terrain.SALT_MARSH: "salt_marsh",
	Tile.Terrain.WETLAND: "wetland",
	Tile.Terrain.FLOODPLAIN: "floodplain",
	Tile.Terrain.WARFT: "warft",
}

var _generator: WorldGenerator
var _noise := FastNoiseLite.new()
var _landscape: LandscapeRules


func _init(
	world_seed: int, generator: WorldGenerator, landscape := LandscapeRules.default_rules()
) -> void:
	_generator = generator
	_landscape = landscape
	_noise.seed = world_seed + SEED_OFFSET
	_noise.frequency = 1.0 / landscape.value("surge", "noise_size")


## The height of a tile of this terrain: its base, and the noise on top.
func at(world_pos: Vector2i, terrain: Tile.Terrain) -> float:
	var base := _base_at(world_pos, terrain)
	if base >= NEVER_FLOODED:
		return base
	return base + _landscape.value("surge", "noise") * _noise.get_noise_2d(world_pos.x, world_pos.y)


func _base_at(world_pos: Vector2i, terrain: Tile.Terrain) -> float:
	if terrain == Tile.Terrain.GRASS or terrain == Tile.Terrain.SOIL:
		var inland := maxf(0.0, world_pos.x - _generator.first_land_x(world_pos.y))
		var rise: float = _landscape.value("surge", "land_rise") * inland
		return minf(
			_landscape.value("surge", "land_at_dyke") + rise, _landscape.value("surge", "land_top")
		)
	if BASE_KEYS.has(terrain):
		return _landscape.value("surge", BASE_KEYS[terrain])
	return NEVER_FLOODED
