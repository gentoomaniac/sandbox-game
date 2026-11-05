class_name HitParticles
extends Node2D
## Short-lived pixel particles for hits (see HitEffect): each is one art pixel, drawn as a
## rect so it stays crisp, and tinted by the day like the world around it. Not GPUParticles,
## which would not keep to the art grid.

const GREENS: Array[Color] = [Color("7fb24a"), Color("5f9a3a"), Color("45802f")]
const AUTUMN_COLORS: Array[Color] = [Color("d9822b"), Color("b8432a"), Color("e0b030")]
const NEEDLE_COLORS: Array[Color] = [Color("2f5a35"), Color("25472b")]
const SNOW_COLORS: Array[Color] = [Color("f4f8ff"), Color("dce8f4")]
const SPLINTER_COLORS: Array[Color] = [Color("a9a9b0"), Color("8a8a92"), Color("6c6c74")]
## Frequency of the sway of falling leaves, in radians per second.
const SWAY_RATE := 14.0
## The last share of a particle's life in which it fades out.
const FADE_SHARE := 0.4

## How each kind is thrown, in pixels and seconds. `count`: least and most particles;
## `spread`: half the size of the area they start in; `sideways`: the most horizontal speed
## either way; `vertical`: least and most vertical speed (down is positive); `gravity`: pull
## down; `sway`: how far a particle swings to the sides while it flies.
const SPECS := {
	HitEffect.Kind.LEAVES_GREEN:
	{
		"count": Vector2i(2, 4),
		"spread": Vector2(9, 6),
		"sideways": 6.0,
		"vertical": Vector2(12, 16),
		"gravity": 0.0,
		"sway": 3.0,
		"life": 0.7,
		"colors": GREENS,
	},
	HitEffect.Kind.LEAVES_AUTUMN:
	{
		"count": Vector2i(2, 4),
		"spread": Vector2(9, 6),
		"sideways": 6.0,
		"vertical": Vector2(12, 16),
		"gravity": 0.0,
		"sway": 3.0,
		"life": 0.7,
		"colors": AUTUMN_COLORS,
	},
	HitEffect.Kind.NEEDLES:
	{
		"count": Vector2i(3, 4),
		"spread": Vector2(8, 8),
		"sideways": 4.0,
		"vertical": Vector2(14, 18),
		"gravity": 0.0,
		"sway": 1.0,
		"life": 0.6,
		"colors": NEEDLE_COLORS,
	},
	HitEffect.Kind.SNOW:
	{
		"count": Vector2i(6, 8),
		"spread": Vector2(6, 4),
		"sideways": 14.0,
		"vertical": Vector2(-10, 2),
		"gravity": 30.0,
		"sway": 0.0,
		"life": 0.5,
		"colors": SNOW_COLORS,
	},
	HitEffect.Kind.SPLINTERS:
	{
		"count": Vector2i(3, 5),
		"spread": Vector2(2, 2),
		"sideways": 36.0,
		"vertical": Vector2(-55, -30),
		"gravity": 170.0,
		"sway": 0.0,
		"life": 0.55,
		"colors": SPLINTER_COLORS,
	},
}

var _particles: Array[Particle] = []
var _random := RandomNumberGenerator.new()


class Particle:
	var start: Vector2
	var velocity: Vector2
	var gravity: float
	var sway: float
	var phase: float
	var life: float
	var color: Color
	var age := 0.0

	func position_now() -> Vector2:
		var swing := sway * sin(phase + age * SWAY_RATE)
		return start + velocity * age + Vector2(swing, 0.5 * gravity * age * age)


func particle_count() -> int:
	return _particles.size()


## Starts the particles of `kind` around `origin`, in world pixels.
func emit(kind: HitEffect.Kind, origin: Vector2) -> void:
	if kind == HitEffect.Kind.NONE:
		return
	var spec: Dictionary = SPECS[kind]
	var spread: Vector2 = spec["spread"]
	var vertical: Vector2 = spec["vertical"]
	var colors: Array[Color] = spec["colors"]
	for _i in _random.randi_range(spec["count"].x, spec["count"].y):
		var particle := Particle.new()
		particle.start = (
			origin
			+ Vector2(
				_random.randf_range(-spread.x, spread.x), _random.randf_range(-spread.y, spread.y)
			)
		)
		particle.velocity = Vector2(
			_random.randf_range(-spec["sideways"], spec["sideways"]),
			_random.randf_range(vertical.x, vertical.y)
		)
		particle.gravity = spec["gravity"]
		particle.sway = spec["sway"]
		particle.phase = _random.randf_range(0.0, TAU)
		particle.life = spec["life"]
		particle.color = colors[_random.randi() % colors.size()]
		_particles.append(particle)
	queue_redraw()


func advance(delta: float) -> void:
	for particle in _particles:
		particle.age += delta
	_particles = _particles.filter(func(p: Particle) -> bool: return p.age < p.life)
	queue_redraw()


func _process(delta: float) -> void:
	if not _particles.is_empty():
		advance(delta)


func _draw() -> void:
	for particle in _particles:
		var color := particle.color
		color.a = clampf((1.0 - particle.age / particle.life) / FADE_SHARE, 0.0, 1.0)
		draw_rect(Rect2(particle.position_now().floor(), Vector2.ONE), color)
