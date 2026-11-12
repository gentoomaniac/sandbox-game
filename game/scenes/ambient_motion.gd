class_name AmbientMotion
extends RefCounted
## The world moving in the wind, view only: plants sway, water ripples, fires burn and lean,
## lily pads drift, rain splashes on the ground and the tide comes and goes on the mud. It is all
## done by shaders, so it costs no nodes or scripts per object: this holds their materials, which
## the tile sets put on the tiles that move (see ObjectTileset and TerrainTileset), and gives them
## the wind every frame (`update`) and the tide (`show_tide`). The swinging, burning and splashing
## run on the shaders' own clock; only what builds up with the wind (how far the ripples drifted)
## is kept here.
##
## Everything moves in whole art pixels, and on a calm day hardly at all. The static functions
## turn the weather into the shaders' numbers. The shaders work on the pixels of the art they move
## (see art_scale.gdshaderinc): the plants', the crops', the ground's (water, mud, lily pads and
## the plants of the decoration layer), the fire's and the rain's splashes are the world's, as they
## are drawn at 32 px, but in the classic art (see ArtSet) the plants', the classic crops' and the
## ground's are the 16 px art's again.

const OBJECT_SWAY_SHADER := preload("res://game/scenes/object_sway.gdshader")
const DECORATION_SWAY_SHADER := preload("res://game/scenes/decoration_sway.gdshader")
const LILY_PAD_SHADER := preload("res://game/scenes/lily_pad.gdshader")
const WATER_SHADER := preload("res://game/scenes/water.gdshader")
const MUD_SHADER := preload("res://game/scenes/mud.gdshader")
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
## Gusts are fronts that sweep downwind across the world this far apart, at this speed (pixels
## and pixels per second): the same numbers as sway.gdshaderinc, change one, change the other.
const GUST_SPACING := 360.0
const GUST_SPEED := 90.0
## The shaders' clock starts over after this many seconds (Godot's default rollover), which
## the front's period divides evenly, so the fronts do not jump.
const SHADER_TIME_ROLLOVER := 3600.0
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
const FIRE_LEAN_PER_WIND := 0.6
const MAX_FIRE_LEAN := 10.0
## How much taller a flame grows in a storm across the screen (a share of its height).
const MAX_FIRE_STRETCH := 0.3
## The chance that a cell of rain_splashes.gdshader (24×20 pixels) has a splash in a cycle
## (0.6 s), in the heaviest rain.
const MAX_SPLASH_CHANCE := 0.45

## How the plants among the objects bend, by type: the pixels above the bottom of their cell
## that stay put (`stem`, a trunk) and where they bend the most (`top`), how far (`strength`,
## a share of the wind's sway) and how fast they swing (`frequency`, per second). Measured on
## the art drawn at 32 px, in the world's pixels; types that are not here stand still (the dead
## tree is a bare snag, too stiff to sway). The grass, the reeds and the fern bend most, so their
## tips flick in a light air; the bushes and the sapling less; the big trees least and slowest,
## so they stand still in a light air (the user, 2026-11-08: "grass and crops usually move more
## than large trees"). The whole is calm: the plants bend half as far on screen as the doubled
## 16 px art did.
const SWAY_PROFILES := {
	WorldObjectTypes.OAK: {"stem": 44.0, "top": 126.0, "strength": 0.5, "frequency": 0.35},
	WorldObjectTypes.SPRUCE: {"stem": 18.0, "top": 136.0, "strength": 0.4, "frequency": 0.4},
	WorldObjectTypes.PINE: {"stem": 70.0, "top": 150.0, "strength": 0.5, "frequency": 0.35},
	WorldObjectTypes.BEECH: {"stem": 56.0, "top": 124.0, "strength": 0.45, "frequency": 0.35},
	WorldObjectTypes.BIRCH: {"stem": 44.0, "top": 134.0, "strength": 0.6, "frequency": 0.5},
	WorldObjectTypes.ALDER: {"stem": 40.0, "top": 132.0, "strength": 0.4, "frequency": 0.4},
	WorldObjectTypes.WILLOW: {"stem": 38.0, "top": 114.0, "strength": 0.5, "frequency": 0.45},
	WorldObjectTypes.SAPLING: {"stem": 8.0, "top": 50.0, "strength": 0.8, "frequency": 0.7},
	WorldObjectTypes.BERRY_BUSH: {"stem": 6.0, "top": 42.0, "strength": 0.7, "frequency": 0.6},
	WorldObjectTypes.SHRUB: {"stem": 4.0, "top": 34.0, "strength": 0.7, "frequency": 0.6},
	WorldObjectTypes.FERN_BUSH: {"stem": 4.0, "top": 36.0, "strength": 1.3, "frequency": 0.8},
	WorldObjectTypes.TALL_GRASS: {"stem": 3.0, "top": 42.0, "strength": 1.6, "frequency": 0.9},
	WorldObjectTypes.REEDS: {"stem": 4.0, "top": 60.0, "strength": 1.5, "frequency": 0.7},
}
## Every crop bends like this, up to the top of its cell, in the pixels of its art: as much as
## the grass, so more than the big trees (see SWAY_PROFILES).
const CROP_SWAY := {"stem": 1.0, "strength": 1.3, "frequency": 0.8}
const DECORATION_SWAY := {"strength": 0.5, "frequency": 0.9}

## The fires, by type: their cell, the strip of their flame and where its box is in the cell
## (FIREPLACE_FLAME in tools/art/camp.py and HEARTH_FLAME in tools/art/interior.py, the same in
## the classic art), the row the flame's tip usually reaches and how high the sparks rise from
## there, in the pixels of the world: fire.gdshader works on the flame drawn at 32 px per tile.
const FIRE_PROFILES := {
	WorldObjectTypes.FIREPLACE:
	{
		"cell_size": Vector2(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT),
		"flames": "res://assets/fire/fireplace.png",
		"box_position": Vector2(32.0, 102.0),
		"flame_top": 114.0,
		"spark_rise": 32.0,
	},
	WorldObjectTypes.HEARTH:
	{
		"cell_size": Vector2(64.0, 128.0),
		"flames": "res://assets/fire/hearth.png",
		"box_position": Vector2(16.0, 52.0),
		"flame_top": 68.0,
		"spark_rise": 12.0,
	},
}

## Which decorations sway, per terrain layer, in the order of the decoration atlas row (see
## TerrainTileset.DECORATION_KINDS and the art generator). Pebbles, fallen leaves, puddles and
## toadstools stay still, and so does a tile that mixes pebbles with a tuft; layers that are
## not here have none that sway. Decorations on water are lily pads, which drift instead, and
## all the meadow flowers (TerrainTileset.FLOWER_ROW) sway.
const SWAYING_DECORATIONS := {
	TerrainTileset.Layer.FLOODPLAIN: [true, true, true, false],
	TerrainTileset.Layer.WETLAND: [false, false, true, true, true, true],
	TerrainTileset.Layer.GRASS: [true, false, true, true, true, false],
	TerrainTileset.Layer.LUSH_GRASS: [true, true, false, true, false],
	TerrainTileset.Layer.DRY_GRASS: [true, false, true, false, false],
	TerrainTileset.Layer.SALT_MARSH: [true, true, false, true],
	TerrainTileset.Layer.WARFT: [true, true],
}

## On the water layer of the terrain, and on the node that draws the rain's splashes.
var water := _material(WATER_SHADER)
## On the mud layer of the terrain: the tide (see `show_tide`), whose water ripples like the river.
var mud := _material(MUD_SHADER)
var splashes := _native_material(RAIN_SPLASH_SHADER)
var decoration_sway := _material(DECORATION_SWAY_SHADER)
var lily_pads := _material(LILY_PAD_SHADER)
## The wind (m/s, the way it blows) as it was shown last (see `update`), which the leaves of the
## trees follow too.
var wind := Vector2.ZERO
## The chance of a splash now (see MAX_SPLASH_CHANCE): 0 when it does not rain.
var splash_chance := 0.0
var _object_materials: Dictionary[StringName, ShaderMaterial] = {}
## By cell size and art scale (x, y and the scale): crops of the same size and art bend alike.
var _crop_materials: Dictionary[Vector3i, ShaderMaterial] = {}
## Every material that sways with the wind, and every fire that leans with it.
var _sway_materials: Array[ShaderMaterial] = [decoration_sway]
var _fire_materials: Array[ShaderMaterial] = []
var _water_drift := Vector2.ZERO


func _init() -> void:
	_set_parameters(decoration_sway, DECORATION_SWAY)
	_show_ground_art_set()
	for type: StringName in SWAY_PROFILES:
		var material := _material(OBJECT_SWAY_SHADER)
		var profile: Dictionary = SWAY_PROFILES[type]
		material.set_shader_parameter("strength", profile["strength"])
		material.set_shader_parameter("frequency", profile["frequency"])
		_object_materials[type] = material
		_sway_materials.append(material)
	_show_plants_art_set()
	var fireplace := fire_material(WorldObjectTypes.FIREPLACE)
	_object_materials[WorldObjectTypes.FIREPLACE] = fireplace
	_fire_materials.append(fireplace)


## Whether an object of this type burns with a visible fire: the hearth and the fireplace.
static func has_flames(type: StringName) -> bool:
	return FIRE_PROFILES.has(type)


## A new material for a fire of `type` (see FIRE_PROFILES) that does not lean: the hearth's,
## indoors, needs no wind.
static func fire_material(type: StringName) -> ShaderMaterial:
	var material := _native_material(FIRE_SHADER)
	var profile: Dictionary = FIRE_PROFILES[type].duplicate()
	profile.erase("flames")
	_set_parameters(material, profile)
	show_flames(material, type)
	material.set_shader_parameter("frames", FIRE_FRAMES)
	material.set_shader_parameter("frames_per_second", FIRE_FRAMES_PER_SECOND)
	return material


## Gives a fire's material the strip of its flame in the chosen art set (see ArtSet).
static func show_flames(material: ShaderMaterial, type: StringName) -> void:
	material.set_shader_parameter("flames", load(ArtSet.path(FIRE_PROFILES[type]["flames"])))


## Shows the flames of the fires outdoors and moves the plants and the ground in the chosen art
## set (see WorldView `show_art_set`).
func show_art_set() -> void:
	show_flames(_object_materials[WorldObjectTypes.FIREPLACE], WorldObjectTypes.FIREPLACE)
	_show_plants_art_set()
	_show_ground_art_set()


## The frame of its flame's loop that a fire shows `seconds` into the shaders' clock, for the
## fire whose cell is at `origin` (pixels). The frame advances FIRE_FRAMES_PER_SECOND
## times a second, and each fire starts its loop at a frame of its own, by its place, so
## neighbours do not burn in step. fire.gdshader picks the frame the same way, with its own
## copy of PositionHash.of (`position_hash`): change one, change the other.
static func fire_frame(seconds: float, origin: Vector2i) -> int:
	return (floori(seconds * FIRE_FRAMES_PER_SECOND) + PositionHash.of(origin)) % FIRE_FRAMES


## The material for the tiles of an object type, or null if it stands still.
func object_material(type: StringName) -> ShaderMaterial:
	return _object_materials.get(type)


## The material for the tiles of a crop's sheet, whose cells are `cell_size`, of art with
## `art_scale` world pixels to its pixel: 1 for the crops drawn at 32 px, ART_16_SCALE for the
## classic sheets.
func crop_material(cell_size: Vector2i, art_scale := 1) -> ShaderMaterial:
	var key := Vector3i(cell_size.x, cell_size.y, art_scale)
	if not _crop_materials.has(key):
		var material := _native_material(OBJECT_SWAY_SHADER)
		_set_parameters(material, CROP_SWAY)
		material.set_shader_parameter("art_scale", float(art_scale))
		# A crop's sheet is no part of the atlas that the frost and snow of the objects fit.
		material.set_shader_parameter("has_cover", false)
		var art_cell_size := Vector2(cell_size) / art_scale
		material.set_shader_parameter("cell_size", art_cell_size)
		material.set_shader_parameter("top", art_cell_size.y)
		_crop_materials[key] = material
		_sway_materials.append(material)
	return _crop_materials[key]


## The material for a decoration tile (its atlas cell: column, and the terrain layer as row),
## or null if it stands still.
func decoration_material(atlas_cell: Vector2i) -> ShaderMaterial:
	if atlas_cell.y == TerrainTileset.Layer.WATER:
		return lily_pads
	if atlas_cell.y == TerrainTileset.FLOWER_ROW:
		return decoration_sway
	var sways: Array = SWAYING_DECORATIONS.get(atlas_cell.y, [])
	if atlas_cell.x < sways.size() and sways[atlas_cell.x]:
		return decoration_sway
	return null


## Shows the wind (m/s, the way it blows) and the rain (0 to 1) as they are now, `delta`
## seconds after the last time.
func update(delta: float, new_wind: Vector2, rain: float) -> void:
	wind = new_wind
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
	for material in [water, mud]:
		material.set_shader_parameter("chop", chop)
		material.set_shader_parameter("drift", _water_drift)
	lily_pads.set_shader_parameter("drift", LILY_DRIFT + LILY_DRIFT_IN_WIND * chop)
	splash_chance = splash_chance_for(rain)
	splashes.set_shader_parameter("chance", splash_chance)


## Shows the tide at `level` (see Tide.level): 0 at low water, 1 at high water.
func show_tide(level: float) -> void:
	mud.set_shader_parameter("tide", level)


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


## How far a gust front is over the cell whose top left is `origin` (world pixels), 0 (between
## fronts) to 1, `shader_seconds` into the shaders' clock (see `shader_time`): as the plants
## see it, times the gust's strength, which `gust_for` gives. Left out is the shader's small
## offset between neighbours.
static func gust_front(origin: Vector2, wind_direction: Vector2, shader_seconds: float) -> float:
	var front := (origin.dot(wind_direction) - shader_seconds * GUST_SPEED) / GUST_SPACING
	return pow(0.5 + 0.5 * sin(TAU * front), 6.0)


## The shaders' clock now, in seconds (TIME in the shaders).
static func shader_time() -> float:
	return fmod(Time.get_ticks_msec() / 1000.0, SHADER_TIME_ROLLOVER)


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


## The ground's shaders work on the pixels of its art: the world's, or the 16 px art's in the
## classic art.
func _show_ground_art_set() -> void:
	for material in [water, mud, decoration_sway, lily_pads]:
		material.set_shader_parameter("art_scale", art_pixel_size())


## The plants sway on the pixels of their art, as the ground does: the profiles, in the world's
## pixels, become the art's.
func _show_plants_art_set() -> void:
	var art_scale := art_pixel_size()
	for type: StringName in SWAY_PROFILES:
		var material := _object_materials[type]
		material.set_shader_parameter("art_scale", art_scale)
		var cell_size := Vector2(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT)
		material.set_shader_parameter("cell_size", cell_size / art_scale)
		material.set_shader_parameter("stem", SWAY_PROFILES[type]["stem"] / art_scale)
		material.set_shader_parameter("top", SWAY_PROFILES[type]["top"] / art_scale)


## How many world pixels an art pixel of the plants and the ground is: 1, or 2 in the classic art.
static func art_pixel_size() -> float:
	return float(TerrainTileset.ART_16_SCALE) if ArtSet.is_classic else 1.0


## A material for a shader of the 16 px art (see art_scale.gdshaderinc).
static func _material(shader: Shader) -> ShaderMaterial:
	var material := _native_material(shader)
	material.set_shader_parameter("art_scale", float(TerrainTileset.ART_16_SCALE))
	return material


## A material for a shader that works in the world's pixels: the fire's and the rain's splashes.
static func _native_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _set_parameters(material: ShaderMaterial, parameters: Dictionary) -> void:
	for parameter: String in parameters:
		material.set_shader_parameter(parameter, parameters[parameter])
