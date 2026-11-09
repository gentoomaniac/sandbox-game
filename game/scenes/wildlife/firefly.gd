class_name Firefly
extends Animal
## A glow-worm drifting over the meadow at dusk: it wanders on slow curves, bobbing, and its
## point of light swells and fades every few seconds. A real light lies over it, as strong as the
## world's other lights are at that hour (see ObjectLight), so it shines out of the dark.

const DRIFT := &"drift"
const FADE := &"fade"
## The sheet's rows: the point of light dark, glowing and at its brightest.
const DARK := &"dark"
const GLOWING := &"glow"
const BRIGHTEST := &"bright"

const SPEED := 9.0
## The most it turns per second, in radians, and how slowly the turning swings from side to side.
const MAX_TURN := 1.6
const TURN_SWING := 0.5
const FLIGHT_HEIGHT := 12.0
const BOB := 4.0
## Seconds from one flash to the next, drawn for each firefly, and the part of that the light
## is on.
const BLINK_SECONDS := Vector2(2.0, 4.0)
const FLASH_SHARE := 0.4
## The glow from which the sheet shows the light glowing, and at its brightest.
const GLOWING_FROM := 0.15
const BRIGHTEST_FROM := 0.7
const FADE_SECONDS := 1.5
const LIGHT_COLOR := Color(0.78, 1.0, 0.45)
const LIGHT_ENERGY := 0.9
const LIGHT_RADIUS_TILES := 1.4

## How bright the point of light is now, from 0 (dark) to 1.
var glow := 0.0
var _heading := 0.0
var _swing_phase := 0.0
var _blink_seconds := 1.0
## How far into its blinks it is, in seconds: each starts at another point, so that they don't
## flash in step.
var _blink_time := 0.0
var _light := PointLight2D.new()


func _init() -> void:
	super(WildlifeRules.FIREFLY)
	shadow_half_width = 0


func _ready() -> void:
	super()
	z_index = 1
	_heading = wildlife.rng.randf() * TAU
	_swing_phase = wildlife.rng.randf() * TAU
	_blink_seconds = wildlife.rng.randf_range(BLINK_SECONDS.x, BLINK_SECONDS.y)
	_blink_time = wildlife.rng.randf() * _blink_seconds
	_light.color = LIGHT_COLOR
	_light.texture = ObjectLight.radial_texture()
	var radius := LIGHT_RADIUS_TILES * WildlifeRules.TILE_SIZE
	_light.texture_scale = radius * 2.0 / ObjectLight.TEXTURE_SIZE
	add_child(_light)
	_enter(DRIFT)


## It fades out where it is.
func dismiss() -> void:
	_enter(FADE)


func _update(delta: float) -> void:
	var seconds := _state_time + _swing_phase
	_lift = FLIGHT_HEIGHT + sin(seconds * 1.7) * BOB
	_heading += sin(seconds * TURN_SWING) * MAX_TURN * delta
	position += Vector2.from_angle(_heading) * SPEED * delta
	_blink_time += delta
	var flash := fposmod(_blink_time / _blink_seconds, 1.0)
	glow = sin(PI * flash / FLASH_SHARE) if flash < FLASH_SHARE else 0.0
	var fade := 1.0
	if _state == FADE:
		fade = 1.0 - _state_time / FADE_SECONDS
		is_done = fade <= 0.0
	_show(fade)


## Shows the light at its glow, faded by `fade`, as strongly as the other lights shine.
func _show(fade: float) -> void:
	var lit := glow * fade
	_play(BRIGHTEST if lit >= BRIGHTEST_FROM else GLOWING if lit >= GLOWING_FROM else DARK, 1.0)
	_light.position.y = -(_lift + WildlifeSprites.SHEETS[kind]["size"].y / 2.0)
	_light.energy = lit * LIGHT_ENERGY * wildlife.world_view.light_strength()
	_light.visible = _light.energy > 0.0
