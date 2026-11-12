class_name GroundLook
extends RefCounted
## The colour of the ground through the year and what lies on it, by shader. The materials of the
## ground (see ground.gdshader and ground_look.gdshaderinc) show the pictures of one season mixing
## into the next, evenly over the whole world (SeasonBlend.ground_mix), with the leaves, frost and
## snow of the weather over them (see CoverMap). Every tile is drawn from the summer atlas, which
## says which pixels it has; the other looks' atlases are only read for their colours, as they have
## the same layout.
##
## The terrain's land layers have `terrain`, tilled soil `soil` (it stays soil-coloured all year,
## and the snow lies on it), the decorations that stand still `decoration`, and those that sway
## AmbientMotion's `decoration_sway`, which this makes the same as the others; the wet look of
## tilled soil has `soil_wet`, which clears where snow lies on the soil.

const GROUND_SHADER := preload("res://game/scenes/ground.gdshader")
const SOIL_WET_SHADER := preload("res://game/scenes/soil_wet.gdshader")

var terrain := _material(GROUND_SHADER)
var soil := _material(GROUND_SHADER)
var decoration := _material(GROUND_SHADER)
var soil_wet := _material(SOIL_WET_SHADER)
var _terrain_materials: Array[ShaderMaterial]
var _decoration_materials: Array[ShaderMaterial]
var _mix := SeasonBlend.GroundMix.new()


## `decoration_sway` is the material of the decorations that sway, which gets the same looks.
func _init(decoration_sway: ShaderMaterial) -> void:
	_terrain_materials = [terrain]
	_decoration_materials = [decoration, decoration_sway]
	show_art_set()


## Shows the colour of the ground of a day (see SeasonBlend.ground_mix).
func show_mix(mix: SeasonBlend.GroundMix) -> void:
	_mix = mix
	_show_looks(_terrain_materials, TerrainTileset.TERRAIN_ATLAS_PATH)
	_show_looks(_decoration_materials, TerrainTileset.DECORATION_ATLAS_PATH)


## Shows the atlases of the chosen art set (see ArtSet), and the pixels of its art.
func show_art_set() -> void:
	var art_scale := AmbientMotion.art_pixel_size()
	for material in [terrain, soil, decoration, soil_wet]:
		material.set_shader_parameter("art_scale", art_scale)
	var summer := _atlas(TerrainTileset.TERRAIN_ATLAS_PATH, SeasonBlend.Look.SUMMER)
	soil.set_shader_parameter("from_look", summer)
	soil.set_shader_parameter("to_look", summer)
	soil.set_shader_parameter("mix_share", 0.0)
	_show_frost_and_snow(soil, TerrainTileset.TERRAIN_ATLAS_PATH)
	_show_looks(_terrain_materials, TerrainTileset.TERRAIN_ATLAS_PATH)
	_show_looks(_decoration_materials, TerrainTileset.DECORATION_ATLAS_PATH)


func _show_looks(materials: Array[ShaderMaterial], atlas_path: String) -> void:
	for material in materials:
		material.set_shader_parameter("from_look", _atlas(atlas_path, _mix.from))
		material.set_shader_parameter("to_look", _atlas(atlas_path, _mix.to))
		material.set_shader_parameter("mix_share", _mix.share)
		_show_frost_and_snow(material, atlas_path)


func _show_frost_and_snow(material: ShaderMaterial, atlas_path: String) -> void:
	material.set_shader_parameter("frost_look", _atlas(atlas_path, SeasonBlend.Look.FROST))
	material.set_shader_parameter("snow_look", _atlas(atlas_path, SeasonBlend.Look.SNOW))


## The atlas at `path` in a look, in the chosen art set.
static func _atlas(path: String, look: SeasonBlend.Look) -> Texture2D:
	return load(ArtSet.path(SeasonalArt.path(path, look)))


static func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
