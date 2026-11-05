class_name HitParticles
extends Node2D
## Short-lived pixel particles for hits (see HitEffect): each is a rect of one to four art
## pixels, so it stays crisp, and tinted by the day like the world around it. Not GPUParticles,
## which would not keep to the art grid.

const GREENS: Array[Color] = [Color("8cc152"), Color("6aa83e"), Color("4f8f33")]
const AUTUMN_COLORS: Array[Color] = [Color("e8902f"), Color("c8452c"), Color("eab836")]
const NEEDLE_COLORS: Array[Color] = [Color("1c4426"), Color("13331b")]
const SNOW_COLORS: Array[Color] = [
	Color("ffffff"), Color("f4f8ff"), Color("b8c4dc"), Color("9fb0d0")
]
const SPLINTER_COLORS: Array[Color] = [
	Color("d0d0d8"), Color("a9a9b0"), Color("7c7c86"), Color("5c5c66")
]
const DUST_COLORS: Array[Color] = [Color("e4e4dc"), Color("c8c8c0")]
## Frequency of the sway of falling leaves, in radians per second.
const SWAY_RATE := 14.0
## The last share of a particle's life in which it fades out.
const FADE_SHARE := 0.4
## How much darker the last pixel of a shaded particle is, which gives a leaf its shape.
const SHADE_DARKENING := 0.4

## How each kind is thrown, in pixels and seconds. `count`: least and most particles;
## `spread`: half the size of the area they start in; `sideways`: the most horizontal speed
## either way; `vertical`: least and most vertical speed (down is positive); `gravity`: pull
## down; `sway`: how far a particle swings to the sides while it flies; `sizes`: the sizes in
## pixels a particle may have; `is_shaded`: whether its last pixel is darker.
const SPECS := {
	HitEffect.Kind.LEAVES_GREEN:
	{
		"count": Vector2i(4, 6),
		"spread": Vector2(12, 4),
		"sideways": 6.0,
		"vertical": Vector2(16, 22),
		"gravity": 0.0,
		"sway": 3.0,
		"life": 1.1,
		"colors": GREENS,
		"sizes": [Vector2(2, 1), Vector2(2, 2)],
		"is_shaded": true,
	},
	HitEffect.Kind.LEAVES_AUTUMN:
	{
		"count": Vector2i(4, 6),
		"spread": Vector2(12, 4),
		"sideways": 6.0,
		"vertical": Vector2(16, 22),
		"gravity": 0.0,
		"sway": 3.0,
		"life": 1.1,
		"colors": AUTUMN_COLORS,
		"sizes": [Vector2(2, 1), Vector2(2, 2)],
		"is_shaded": true,
	},
	HitEffect.Kind.NEEDLES:
	{
		"count": Vector2i(5, 7),
		"spread": Vector2(11, 6),
		"sideways": 4.0,
		"vertical": Vector2(18, 24),
		"gravity": 0.0,
		"sway": 1.0,
		"life": 1.0,
		"colors": NEEDLE_COLORS,
		"sizes": [Vector2(2, 1)],
		"is_shaded": false,
	},
	HitEffect.Kind.SNOW:
	{
		"count": Vector2i(8, 12),
		"spread": Vector2(9, 5),
		"sideways": 16.0,
		"vertical": Vector2(0, 12),
		"gravity": 40.0,
		"sway": 0.0,
		"life": 0.7,
		"colors": SNOW_COLORS,
		"sizes": [Vector2(1, 1), Vector2(2, 1), Vector2(2, 2)],
		"is_shaded": false,
	},
	HitEffect.Kind.SPLINTERS:
	{
		"count": Vector2i(4, 6),
		"spread": Vector2(3, 3),
		"sideways": 30.0,
		"vertical": Vector2(-80, -50),
		"gravity": 220.0,
		"sway": 0.0,
		"life": 0.7,
		"colors": SPLINTER_COLORS,
		"sizes": [Vector2(1, 1), Vector2(2, 1)],
		"is_shaded": false,
	},
	HitEffect.Kind.DUST:
	{
		"count": Vector2i(2, 3),
		"spread": Vector2(3, 2),
		"sideways": 8.0,
		"vertical": Vector2(-12, -3),
		"gravity": 0.0,
		"sway": 0.0,
		"life": 0.3,
		"colors": DUST_COLORS,
		"sizes": [Vector2(1, 1)],
		"is_shaded": false,
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
	var size: Vector2
	var is_shaded: bool
	var age := 0.0

	func position_now() -> Vector2:
		var swing := sway * sin(phase + age * SWAY_RATE)
		return start + velocity * age + Vector2(swing, 0.5 * gravity * age * age)


func particle_count() -> int:
	return _particles.size()


## Starts the particles of `kind` around `origin`, in world pixels. Splinters raise a little
## dust too.
func emit(kind: HitEffect.Kind, origin: Vector2) -> void:
	if kind == HitEffect.Kind.NONE:
		return
	var spec: Dictionary = SPECS[kind]
	var spread: Vector2 = spec["spread"]
	var vertical: Vector2 = spec["vertical"]
	var colors: Array[Color] = spec["colors"]
	var sizes: Array = spec["sizes"]
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
		particle.size = sizes[_random.randi() % sizes.size()]
		particle.is_shaded = spec["is_shaded"]
		_particles.append(particle)
	queue_redraw()
	if kind == HitEffect.Kind.SPLINTERS:
		emit(HitEffect.Kind.DUST, origin)


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
		var top_left := particle.position_now().floor()
		draw_rect(Rect2(top_left, particle.size), color)
		if particle.is_shaded:
			var last_pixel := top_left + particle.size - Vector2.ONE
			draw_rect(Rect2(last_pixel, Vector2.ONE), color.darkened(SHADE_DARKENING))
