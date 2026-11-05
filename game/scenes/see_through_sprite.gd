class_name SeeThroughSprite
extends Sprite2D
## A sprite that turns translucent in a circle around the player while it hides the player
## (see Occlusion and see_through.gdshader). Set `is_occluding`, then call `update` every
## frame: the effect fades in and out so it does not pop.

const SHADER := preload("res://game/scenes/see_through.gdshader")
## The circle is centred on the player's middle, one tile above the feet.
const CENTRE_ABOVE_FEET := TerrainTileset.TILE_SIZE
const RADIUS := 2.0 * TerrainTileset.TILE_SIZE
const INNER_OPACITY := 0.35
const EDGE_SOFTNESS := 4.0
const FADE_SECONDS := 0.15

var is_occluding := false
var _fade := 0.0


func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("radius", RADIUS)
	material.set_shader_parameter("inner_opacity", INNER_OPACITY)
	material.set_shader_parameter("edge_softness", EDGE_SOFTNESS)


## True when it is not occluding and has faded back to normal.
func is_plain() -> bool:
	return not is_occluding and _fade == 0.0


func update(delta: float, player_feet: Vector2) -> void:
	_fade = move_toward(_fade, 1.0 if is_occluding else 0.0, delta / FADE_SECONDS)
	material.set_shader_parameter("fade", _fade)
	material.set_shader_parameter("circle_centre", player_feet - Vector2(0, CENTRE_ABOVE_FEET))
