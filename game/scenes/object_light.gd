class_name ObjectLight
extends PointLight2D
## The light of a world object (see WorldObjectTypes "light"), with a slight flicker.

const TEXTURE_SIZE := 128
## The flicker: two sine waves of different speed, each this fraction of the energy.
const FLICKER := [[7.0, 0.07], [13.3, 0.04]]

static var _texture: GradientTexture2D

## 0 turns the light off, 1 is full strength. Set by whoever knows the time of day.
var strength := 1.0:
	set(value):
		strength = value
		visible = value > 0.0
		set_process(value > 0.0)
var _energy := 1.0
## Keeps neighbouring lights from flickering in step.
var _phase := 0.0


func _init(light: Dictionary, world_pos: Vector2i) -> void:
	color = light["color"]
	_energy = light["energy"]
	_phase = PositionHash.of(world_pos) % 1000
	texture = _radial_texture()
	texture_scale = light["radius_tiles"] * TerrainTileset.TILE_SIZE * 2.0 / TEXTURE_SIZE
	# A little above the tile's centre, where the flame is.
	position = (Vector2(world_pos) + Vector2(0.5, 0.5)) * TerrainTileset.TILE_SIZE
	position.y -= 2.0


func _process(_delta: float) -> void:
	var seconds := Time.get_ticks_msec() / 1000.0
	var flicker := 1.0
	for wave: Array in FLICKER:
		flicker += sin(seconds * wave[0] + _phase) * wave[1]
	energy = _energy * flicker * strength


## White in the middle, fading smoothly to nothing at the edge.
static func _radial_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color(0.3, 0.3, 0.3), Color.BLACK])
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
	return _texture
