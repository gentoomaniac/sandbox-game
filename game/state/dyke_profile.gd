class_name DykeProfile
extends RefCounted
## How high and how strong the dykes the generator lays are, and what a hover says of one (see
## design/world/storm-surge.md). Height is in metres over mean high water, strength from 0 (bare)
## to 1 (well turfed and packed). Both are pure functions of the world seed and the tile, so a
## stretch of dyke shares one value and nothing is saved for a dyke nobody changed. The numbers
## are in the `[surge]` section of data/landscape.cfg.

## Offsets the noise seeds so they are independent of the generator's noises and each other.
const HEIGHT_SEED_OFFSET := 41
const STRENGTH_SEED_OFFSET := 42

## From what strength a dyke is called turfed, and well turfed.
const TURFED_FROM := 0.4
const WELL_TURFED_FROM := 0.7

var _generator: WorldGenerator
var _landscape: LandscapeRules
var _height_noise := FastNoiseLite.new()
var _strength_noise := FastNoiseLite.new()


func _init(
	world_seed: int, generator: WorldGenerator, landscape := LandscapeRules.default_rules()
) -> void:
	_generator = generator
	_landscape = landscape
	var frequency := 1.0 / landscape.value("surge", "dyke_stretch_size")
	_height_noise.seed = world_seed + HEIGHT_SEED_OFFSET
	_height_noise.frequency = frequency
	_strength_noise.seed = world_seed + STRENGTH_SEED_OFFSET
	_strength_noise.frequency = frequency


## Whether a dyke tile belongs to the sea dyke (the generator lays it within DYKE_LINE_REACH of the
## first land of its row); the others run along the river.
func is_sea_dyke(tile: Vector2i) -> bool:
	return tile.x - _generator.first_land_x(tile.y) <= WorldGenerator.DYKE_LINE_REACH


## The height of the dyke the generator laid at a tile.
func height_at(tile: Vector2i) -> float:
	var kind := "sea" if is_sea_dyke(tile) else "river"
	return (
		_landscape.value("surge", kind + "_dyke_height")
		+ (
			_landscape.value("surge", kind + "_dyke_spread")
			* _height_noise.get_noise_2d(tile.x, tile.y)
		)
	)


## The strength of the dyke the generator laid at a tile.
func strength_at(tile: Vector2i) -> float:
	var strength: float = (
		_landscape.value("surge", "dyke_strength")
		+ (
			_landscape.value("surge", "dyke_strength_spread")
			* _strength_noise.get_noise_2d(tile.x, tile.y)
		)
	)
	return clampf(strength, 0.0, 1.0)


## What a hover says of a dyke: "Dyke, 2.1 m, well turfed", with "low" or "high" before the height
## when it is.
func words(height: float, strength: float) -> String:
	var size := ""
	if height < _landscape.value("surge", "low_below"):
		size = "low, "
	elif height > _landscape.value("surge", "high_above"):
		size = "high, "
	var turf := "bare"
	if strength >= WELL_TURFED_FROM:
		turf = "well turfed"
	elif strength >= TURFED_FROM:
		turf = "turfed"
	return "Dyke, %s%.1f m, %s" % [size, height, turf]
