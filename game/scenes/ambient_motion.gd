class_name AmbientMotion
extends RefCounted
## The world moving in the wind, view only: plants sway, water ripples, fires burn and lean,
## lily pads drift and rain splashes on the ground. It is all done by shaders, so it costs no
## nodes or scripts per object: this holds their materials, which the tile sets put on the tiles
## that move (see ObjectTileset and TerrainTileset), and gives them the wind every frame
## (`update`). The swinging, burning and splashing run on the shaders' own clock; only what
## builds up with the wind (how far the ripples drifted) is kept here.
##
## Everything moves in whole art pixels, and on a calm day hardly at all. The static functions
## turn the weather into the shaders' numbers.

const OBJECT_SWAY_SHADER := preload("res://game/scenes/object_sway.gdshader")
const DECORATION_SWAY_SHADER := preload("res://game/scenes/decoration_sway.gdshader")
const LILY_PAD_SHADER := preload("res://game/scenes/lily_pad.gdshader")
const WATER_SHADER := preload("res://game/scenes/water.gdshader")
const FIRE_SHADER := preload("res://game/scenes/fire.gdshader")
const RAIN_SPLASH_SHADER := preload("res://game/scenes/rain_splashes.gdshader")

## The wind (m/s) at which plants sway their most, and how far the top of the bendiest plant
## then swings to either side and leans downwind, in pixels.
const STORM_WIND := 18.0
const MAX_SWAY := 3.0
const MAX_LEAN := 1.5
## The sway grows quickly in a breeze and slowly towards a storm.
const SWAY_CURVE := 0.8
## Gusts start above this wind (m/s) and are at their strongest at STORM_WIND.
const GUSTS_FROM := 3.0
## Water is at its choppiest at this wind (m/s).
const CHOPPY_WIND := 14.0
## Ripples drift a little even without wind, and with it this many pixels per second per m/s.
const WATER_BASE_DRIFT := Vector2(1.0, 0.3)
const WATER_DRIFT_PER_WIND := 0.8
## How far lily pads drift to either side (pixels, before rounding): on a calm day and added
## at the choppiest.
const LILY_DRIFT := 0.6
const LILY_DRIFT_IN_WIND := 0.8
## A flame's loop (see fire.gdshader and tools/art/fire.py): its frames, and how fast it plays.
const FIRE_FRAMES := 6
const FIRE_FRAMES_PER_SECOND := 9.0
## Pixels the top of a flame's box leans per m/s of wind across the screen, and at most. Its tip
## leans about half as far.
const FIRE_LEAN_PER_WIND := 0.3
const MAX_FIRE_LEAN := 5.0
## How much taller a flame grows in a storm across the screen (a share of its height).
const MAX_FIRE_STRETCH := 0.3
## The chance that a cell of rain_splashes.gdshader (12×10 pixels) has a splash in a cycle
## (0.6 s), in the heaviest rain.
const MAX_SPLASH_CHANCE := 0.45

## How the plants among the objects bend, by type: the pixels above the bottom of their cell
## that stay put (`stem`, a trunk) and where they bend the most (`top`), how far (`strength`,
## a share of the wind's sway) and how fast they swing (`frequency`, per second). Measured on
## the art; types that are not here stand still (the dead tree is a bare snag, too stiff to sway).
const SWAY_PROFILES := {
	WorldObjectTypes.OAK: {"stem": 20.0, "top": 62.0, "strength": 1.0, "frequency": 0.35},
	WorldObjectTypes.SPRUCE: {"stem": 8.0, "top": 65.0, "strength": 0.8, "frequency": 0.4},
	WorldObjectTypes.PINE: {"stem": 34.0, "top": 74.0, "strength": 1.0, "frequency": 0.35},
	WorldObjectTypes.BEECH: {"stem": 28.0, "top": 62.0, "strength": 0.9, "frequency": 0.35},
	WorldObjectTypes.WILLOW: {"stem": 26.0, "top": 60.0, "strength": 0.8, "frequency": 0.45},
	WorldObjectTypes.SAPLING: {"stem": 3.0, "top": 22.0, "strength": 0.7, "frequency": 0.7},
	WorldObjectTypes.BERRY_BUSH: {"stem": 3.0, "top": 20.0, "strength": 0.4, "frequency": 0.6},
	WorldObjectTypes.SHRUB: {"stem": 2.0, "top": 16.0, "strength": 0.4, "frequency": 0.6},
	WorldObjectTypes.FERN_BUSH: {"stem": 2.0, "top": 13.0, "strength": 0.7, "frequency": 0.8},
	WorldObjectTypes.TALL_GRASS: {"stem": 1.0, "top": 17.0, "strength": 1.0, "frequency": 0.9},
	WorldObjectTypes.REEDS: {"stem": 2.0, "top": 31.0, "strength": 1.0, "frequency": 0.7},
}
## Every crop bends like this, up to the top of its cell.
const CROP_SWAY := {"stem": 1.0, "strength": 0.6, "frequency": 0.8}
const DECORATION_SWAY := {"strength": 0.5, "frequency": 0.9}

## The fires, by type: their cell, the strip of their flame and where its box is in the cell
## (FIREPLACE_FLAME in tools/art/camp.py and HEARTH_FLAME in tools/art/interior.py), the row
## the flame's tip usually reaches and how high the sparks rise from there (pixels).
const FIRE_PROFILES := {
	WorldObjectTypes.FIREPLACE:
	{
		"cell_size": Vector2(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT),
		"flames": preload("res://assets/fire/fireplace.png"),
		"box_position": Vector2(16.0, 51.0),
		"flame_top": 57.0,
		"spark_rise": 16.0,
	},
	WorldObjectTypes.HEARTH:
	{
		"cell_size": Vector2(32.0, 32.0),
		"flames": preload("res://assets/fire/hearth.png"),
		"box_position": Vector2(8.0, 10.0),
		"flame_top": 14.0,
		"spark_rise": 4.0,
	},
}

## Which decorations sway, per terrain layer, in the order of the decoration atlas row (see
## TerrainTileset.DECORATION_KINDS and the art generator). Pebbles, fallen leaves, puddles and
## toadstools stay still, and so does a tile that mixes pebbles with a tuft; layers that are
## not here have none that sway. Decorations on water are lily pads, which drift instead.
const SWAYING_DECORATIONS := {
	TerrainTileset.Layer.FLOODPLAIN: [true, true, true, true, true, false],
	TerrainTileset.Layer.WETLAND: [false, false, true, true, true, true],
	TerrainTileset.Layer.GRASS: [true, true, true, true, true, false, true, true, false],
	TerrainTileset.Layer.LUSH_GRASS: [true, true, true, true, false, true, false],
	TerrainTileset.Layer.DRY_GRASS: [true, false, true, true, false, false],
}

## On the water layer of the terrain, and on the node that draws the rain's splashes.
var water := _material(WATER_SHADER)
var splashes := _material(RAIN_SPLASH_SHADER)
var decoration_sway := _material(DECORATION_SWAY_SHADER)
var lily_pads := _material(LILY_PAD_SHADER)
## The chance of a splash now (see MAX_SPLASH_CHANCE): 0 when it does not rain.
var splash_chance := 0.0
var _object_materials: Dictionary[StringName, ShaderMaterial] = {}
## By cell size: crops of the same size bend alike.
var _crop_materials: Dictionary[Vector2i, ShaderMaterial] = {}
## Every material that sways with the wind, and every fire that leans with it.
var _sway_materials: Array[ShaderMaterial] = [decoration_sway]
var _fire_materials: Array[ShaderMaterial] = []
var _water_drift := Vector2.ZERO


func _init() -> void:
	_set_parameters(decoration_sway, DECORATION_SWAY)
	for type: StringName in SWAY_PROFILES:
		var material := _material(OBJECT_SWAY_SHADER)
		_set_parameters(material, SWAY_PROFILES[type])
		_object_materials[type] = material
		_sway_materials.append(material)
	var fireplace := fire_material(WorldObjectTypes.FIREPLACE)
	_object_materials[WorldObjectTypes.FIREPLACE] = fireplace
	_fire_materials.append(fireplace)


## A new material for a fire of `type` (see FIRE_PROFILES) that does not lean: the hearth's,
## indoors, needs no wind.
static func fire_material(type: StringName) -> ShaderMaterial:
	var material := _material(FIRE_SHADER)
	_set_parameters(material, FIRE_PROFILES[type])
	material.set_shader_parameter("frames", FIRE_FRAMES)
	material.set_shader_parameter("frames_per_second", FIRE_FRAMES_PER_SECOND)
	return material


## The frame of its flame's loop that a fire shows `seconds` into the shaders' clock, for the
## fire whose cell is at `origin` (world pixels). The frame advances FIRE_FRAMES_PER_SECOND
## times a second, and each fire starts its loop at a frame of its own, by its place, so
## neighbours do not burn in step. fire.gdshader picks the frame the same way, with its own
## copy of PositionHash.of (`position_hash`): change one, change the other.
static func fire_frame(seconds: float, origin: Vector2i) -> int:
	return (floori(seconds * FIRE_FRAMES_PER_SECOND) + PositionHash.of(origin)) % FIRE_FRAMES


## The material for the tiles of an object type, or null if it stands still.
func object_material(type: StringName) -> ShaderMaterial:
	return _object_materials.get(type)


## The material for the tiles of a crop's sheet, whose cells are `cell_size`.
func crop_material(cell_size: Vector2i) -> ShaderMaterial:
	if not _crop_materials.has(cell_size):
		var material := _material(OBJECT_SWAY_SHADER)
		_set_parameters(material, CROP_SWAY)
		material.set_shader_parameter("cell_size", Vector2(cell_size))
		material.set_shader_parameter("top", float(cell_size.y))
		_crop_materials[cell_size] = material
		_sway_materials.append(material)
	return _crop_materials[cell_size]


## The material for a decoration tile (its atlas cell: column, and the terrain layer as row),
## or null if it stands still.
func decoration_material(atlas_cell: Vector2i) -> ShaderMaterial:
	if atlas_cell.y == TerrainTileset.Layer.WATER:
		return lily_pads
	var sways: Array = SWAYING_DECORATIONS.get(atlas_cell.y, [])
	if atlas_cell.x < sways.size() and sways[atlas_cell.x]:
		return decoration_sway
	return null


## Shows the wind (m/s, the way it blows) and the rain (0 to 1) as they are now, `delta`
## seconds after the last time.
func update(delta: float, wind: Vector2, rain: float) -> void:
	var speed := wind.length()
	for material in _sway_materials:
		material.set_shader_parameter("sway", sway_for(speed))
		material.set_shader_parameter("lean", lean_for(wind))
		material.set_shader_parameter("gust", gust_for(speed))
		material.set_shader_parameter("wind_direction", wind.normalized())
	for material in _fire_materials:
		material.set_shader_parameter("lean", fire_lean_for(wind))
		material.set_shader_parameter("stretch", fire_stretch_for(wind))
	var chop := chop_for(speed)
	_water_drift += (WATER_BASE_DRIFT + wind * WATER_DRIFT_PER_WIND) * delta
	water.set_shader_parameter("chop", chop)
	water.set_shader_parameter("drift", _water_drift)
	lily_pads.set_shader_parameter("drift", LILY_DRIFT + LILY_DRIFT_IN_WIND * chop)
	splash_chance = splash_chance_for(rain)
	splashes.set_shader_parameter("chance", splash_chance)


## How far the top of the bendiest plant swings to either side in a wind of `speed` m/s, in
## pixels: about half a pixel in a light air (2 m/s), so only the tips of the bendiest plants
## flick now and then, and MAX_SWAY in a storm.
static func sway_for(speed: float) -> float:
	return MAX_SWAY * pow(clampf(speed / STORM_WIND, 0.0, 1.0), SWAY_CURVE)


## How far the top of the bendiest plant leans downwind, in pixels (+ is right): only the wind
## across the screen shows.
static func lean_for(wind: Vector2) -> float:
	return MAX_LEAN * clampf(wind.x / STORM_WIND, -1.0, 1.0)


## How much the gusts add to the sway, 0 (none) to 1 (in a storm).
static func gust_for(speed: float) -> float:
	return clampf((speed - GUSTS_FROM) / (STORM_WIND - GUSTS_FROM), 0.0, 1.0)


## How choppy the water is, 0 (still) to 1.
static func chop_for(speed: float) -> float:
	return clampf(speed / CHOPPY_WIND, 0.0, 1.0)


## How far the top of a flame's box leans downwind, in pixels (+ is right).
static func fire_lean_for(wind: Vector2) -> float:
	return clampf(wind.x * FIRE_LEAN_PER_WIND, -MAX_FIRE_LEAN, MAX_FIRE_LEAN)


## How much taller a flame grows as it leans in the wind (a share of its height): 0 when calm,
## MAX_FIRE_STRETCH in a storm across the screen.
static func fire_stretch_for(wind: Vector2) -> float:
	return MAX_FIRE_STRETCH * clampf(absf(wind.x) / STORM_WIND, 0.0, 1.0)


## The chance of a splash per cell and cycle (see rain_splashes.gdshader) in rain of intensity
## `rain` (0 to 1).
static func splash_chance_for(rain: float) -> float:
	return MAX_SPLASH_CHANCE * clampf(rain, 0.0, 1.0)


static func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _set_parameters(material: ShaderMaterial, parameters: Dictionary) -> void:
	for parameter: String in parameters:
		material.set_shader_parameter(parameter, parameters[parameter])
