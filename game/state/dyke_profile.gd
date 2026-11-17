class_name DykeProfile
extends RefCounted
## How high and how strong the dykes the generator lays are, and what a hover says of one (see
## design/world/storm-surge.md). Height is in metres over mean high water, strength from 0 (bare)
## to 1 (well turfed and packed). Both are pure functions of the world seed and the tile, so a
## stretch of dyke shares one value and nothing is saved for a dyke nobody changed. The numbers
## are in the `[surge]` section of data/landscape.cfg.

## What a dyke the game changed keeps in its object's state, whole numbers so that a save holds no
## fractions: the height in centimetres and the strength in percent. Without them the dyke is as
## the generator laid it. The changed object is an edit of the world, saved with the others.
const HEIGHT_KEY := "height_cm"
const STRENGTH_KEY := "strength_pct"
## The tallest dyke a save may hold, in centimetres.
const MAX_HEIGHT_CM := 400

## Offsets the noise seeds so they are independent of the generator's noises and each other.
const HEIGHT_SEED_OFFSET := 41
const STRENGTH_SEED_OFFSET := 42

## The looks of a dyke by its height, and torn while the sea has damaged it (see `look`): the
## names of its other rows in the atlas (WorldObjectTypes `look_rows`); a dyke of no special height
## has its type's own row.
const LOW := &"low"
const HIGH := &"high"
const TORN := &"torn"
const NORMAL := &""

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
	return tile.x - _generator.first_land_x(tile.y) <= DykeLayout.LINE_REACH


## The height of a dyke object, as the generator laid it or as the game changed it.
func height_of(dyke: WorldObject) -> float:
	return dyke.state[HEIGHT_KEY] / 100.0 if dyke.state.has(HEIGHT_KEY) else height_at(dyke.pos)


## The strength of a dyke object, as the generator laid it or as the game changed it.
func strength_of(dyke: WorldObject) -> float:
	return (
		dyke.state[STRENGTH_KEY] / 100.0 if dyke.state.has(STRENGTH_KEY) else strength_at(dyke.pos)
	)


## Gives a dyke object of the world a new height and strength: an edit that outlives its chunk.
func change(world: World, dyke: WorldObject, height: float, strength: float) -> void:
	dyke.state[HEIGHT_KEY] = clampi(roundi(height * 100.0), 0, MAX_HEIGHT_CM)
	dyke.state[STRENGTH_KEY] = clampi(roundi(strength * 100.0), 0, 100)
	world.change_object(dyke)


## Gives a dyke object of the world the height and strength the generator laid there again.
func restore(world: World, dyke: WorldObject) -> void:
	dyke.state.erase(HEIGHT_KEY)
	dyke.state.erase(STRENGTH_KEY)
	world.change_object(dyke)


## The height of the lowest sea dyke of the loaded chunks, in metres; INF with none.
func lowest_sea_dyke_height(world: World) -> float:
	var lowest := INF
	for coords in world.loaded_chunk_coords():
		for object in world.chunk_at(coords).objects():
			if object.type == WorldObjectTypes.DYKE and is_sea_dyke(object.pos):
				lowest = minf(lowest, height_of(object))
	return lowest


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
func words(dyke: WorldObject) -> String:
	var height := height_of(dyke)
	var strength := strength_of(dyke)
	var size := String(_size(height))
	if not size.is_empty():
		size += ", "
	var turf := "bare"
	if strength >= WELL_TURFED_FROM:
		turf = "well turfed"
	elif strength >= TURFED_FROM:
		turf = "turfed"
	return "Dyke, %s%.1f m, %s" % [size, height, turf]


## The look a dyke is drawn in: TORN while it `is_torn` (damaged and not mended yet, see
## FloodState `is_torn`), else LOW under `low_below`, HIGH over `high_above`, or NORMAL.
func look(dyke: WorldObject, is_torn := false) -> StringName:
	return TORN if is_torn else _size(height_of(dyke))


func _size(height: float) -> StringName:
	if height < _landscape.value("surge", "low_below"):
		return LOW
	if height > _landscape.value("surge", "high_above"):
		return HIGH
	return NORMAL


## The checks of the state this feature keeps in a WorldObject, by key, for the save
## validator (SaveObjectChecks).
static func state_checks(ctx: SaveContext) -> Dictionary[String, Callable]:
	return {
		HEIGHT_KEY: _check_measure.bind(ctx, HEIGHT_KEY),
		STRENGTH_KEY: _check_measure.bind(ctx, STRENGTH_KEY),
	}


## The height (in centimetres) or strength (in percent) of a dyke the game changed.
static func _check_measure(
	state: Dictionary,
	_type: Dictionary,
	path: String,
	_drop: Callable,
	ctx: SaveContext,
	key: String
) -> void:
	if not ctx.is_kind(state[key], SaveContext.Kind.WHOLE):
		ctx.report(path + " state", "%s should be a whole number" % key)
		return
	var most := MAX_HEIGHT_CM if key == HEIGHT_KEY else 100
	ctx.check_between(state[key], 0, most, path + " state", key)
