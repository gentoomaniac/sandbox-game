class_name HitParticles
extends Node2D
## Short-lived pixel particles for hits (see HitEffect): each is a small shape of whole art
## pixels, one to five across, so it stays crisp, and tinted by the day like the world around it.
## Not GPUParticles, which would not keep to the art grid. Those of three pixels or more both ways
## have their corners left out, so a leaf or a flake is round.

## Each palette is brighter than the foliage it falls from, or it is lost against it: yellow
## greens under a green canopy, dry brown-green needles under a dark spruce, bright ochre,
## copper and tan under the brown autumn oaks.
const GREENS: Array[Color] = [Color("c6e070"), Color("a9d158"), Color("e2e67e")]
const AUTUMN_COLORS: Array[Color] = [Color("f0c060"), Color("e88a40"), Color("d8b078")]
const NEEDLE_COLORS: Array[Color] = [Color("c0c860"), Color("d4a862"), Color("a2c252")]
const SNOW_COLORS: Array[Color] = [Color("ffffff"), Color("ffffff"), Color("eef4ff")]
const SPLINTER_COLORS: Array[Color] = [
	Color("e4e4ea"), Color("b8b8c0"), Color("8a8a94"), Color("66666f")
]
const DUST_COLORS: Array[Color] = [Color("e4e4dc"), Color("c8c8c0")]
## Light blue and white drops, darker on their shaded side, so a drop shows against pale ground
## (snow, the sleeping bag) as well as against grass.
const SWEAT_COLORS: Array[Color] = [Color("92b4bd"), Color("92b4bd"), Color("e6eef2")]
## Frequency of the sway of falling leaves, in radians per second.
const SWAY_RATE := 7.0
## How much slower a particle tumbles up and down than it sways to the sides.
const TUMBLE_RATE_FACTOR := 0.6
## The last share of a particle's life in which it fades out.
const FADE_SHARE := 0.3
## How much darker the shaded side of a particle is (its bottom row and right column, away from
## the light from the top left), which gives a leaf its shape.
const SHADE_DARKENING := 0.45

## How each kind is thrown, in pixels and seconds. `count`: least and most
## particles; `spread`: half the size of the area they start in; `sideways`: the most horizontal
## speed either way; `vertical`: least and most vertical speed (down is positive); `gravity`: pull
## down; `sway`: how far a particle swings to the sides while it flies; `sizes`: the sizes in
## pixels a particle may have; `is_shaded`: whether its shaded side is darker. With `is_outward`
## (optional) a particle starts `spread.x` to the left or right of the origin, and is thrown
## away from it at between half of `sideways` and all of it.
## Leaves and needles fall far enough to leave the canopy and land on the ground beside the
## trunk, so they are seen against it too.
const SPECS := {
	HitEffect.Kind.LEAVES_GREEN:
	{
		"count": Vector2i(6, 8),
		"spread": Vector2(28, 12),
		"sideways": 20.0,
		"vertical": Vector2(44, 64),
		"gravity": 0.0,
		"sway": 6.0,
		"life": 1.2,
		"colors": GREENS,
		"sizes": [Vector2(4, 3), Vector2(3, 3), Vector2(5, 3)],
		"is_shaded": true,
	},
	HitEffect.Kind.LEAVES_AUTUMN:
	{
		"count": Vector2i(6, 8),
		"spread": Vector2(28, 12),
		"sideways": 20.0,
		"vertical": Vector2(44, 64),
		"gravity": 0.0,
		"sway": 6.0,
		"life": 1.2,
		"colors": AUTUMN_COLORS,
		"sizes": [Vector2(4, 3), Vector2(3, 3), Vector2(5, 3)],
		"is_shaded": true,
	},
	HitEffect.Kind.NEEDLES:
	{
		"count": Vector2i(7, 9),
		"spread": Vector2(20, 16),
		"sideways": 12.0,
		"vertical": Vector2(52, 68),
		"gravity": 0.0,
		"sway": 3.0,
		"life": 1.1,
		"colors": NEEDLE_COLORS,
		"sizes": [Vector2(5, 1), Vector2(1, 5), Vector2(4, 1)],
		"is_shaded": false,
	},
	HitEffect.Kind.SNOW:
	{
		"count": Vector2i(10, 14),
		"spread": Vector2(20, 16),
		"sideways": 24.0,
		"vertical": Vector2(8, 32),
		"gravity": 90.0,
		"sway": 0.0,
		"life": 1.1,
		"colors": SNOW_COLORS,
		"sizes": [Vector2(2, 2), Vector2(3, 2), Vector2(3, 3), Vector2(4, 3)],
		"is_shaded": false,
	},
	HitEffect.Kind.SPLINTERS:
	{
		"count": Vector2i(5, 7),
		"spread": Vector2(6, 6),
		"sideways": 64.0,
		"vertical": Vector2(-160, -100),
		"gravity": 440.0,
		"sway": 0.0,
		"life": 0.7,
		"colors": SPLINTER_COLORS,
		"sizes": [Vector2(2, 1), Vector2(3, 1), Vector2(4, 2)],
		"is_shaded": false,
	},
	HitEffect.Kind.DUST:
	{
		"count": Vector2i(2, 3),
		"spread": Vector2(6, 4),
		"sideways": 16.0,
		"vertical": Vector2(-24, -6),
		"gravity": 0.0,
		"sway": 0.0,
		"life": 0.3,
		"colors": DUST_COLORS,
		"sizes": [Vector2(2, 2), Vector2(2, 1)],
		"is_shaded": false,
	},
	HitEffect.Kind.SWEAT:
	{
		"count": Vector2i(1, 1),
		"spread": Vector2(10, 2),
		"sideways": 32.0,
		"vertical": Vector2(-96, -72),
		"gravity": 400.0,
		"sway": 0.0,
		"life": 0.8,
		"colors": SWEAT_COLORS,
		"sizes": [Vector2(3, 4), Vector2(2, 3)],
		"is_shaded": true,
		"is_outward": true,
	},
	HitEffect.Kind.SWEAT_HEAVY:
	{
		"count": Vector2i(2, 3),
		"spread": Vector2(10, 2),
		"sideways": 52.0,
		"vertical": Vector2(-128, -88),
		"gravity": 400.0,
		"sway": 0.0,
		"life": 0.9,
		"colors": SWEAT_COLORS,
		"sizes": [Vector2(3, 4), Vector2(2, 3)],
		"is_shaded": true,
		"is_outward": true,
	},
}

var _particles: Array[Particle] = []
var _random := RandomNumberGenerator.new()


class Particle:
	## In pixels, as everything of a particle.
	var start: Vector2
	var velocity: Vector2
	var gravity: float
	var sway: float
	## How far a particle swings up and down, a little slower than it sways to the sides.
	var tumble := 0.0
	var phase: float
	var life: float
	var color: Color
	var size: Vector2
	var is_shaded: bool
	var age := 0.0

	func position_now() -> Vector2:
		var swing := sway * sin(phase + age * SWAY_RATE)
		var bob := tumble * sin(phase * 1.7 + age * SWAY_RATE * TUMBLE_RATE_FACTOR)
		return start + velocity * age + Vector2(swing, 0.5 * gravity * age * age + bob)


func particle_count() -> int:
	return _particles.size()


## Takes away every particle in the air.
func clear() -> void:
	_particles.clear()
	queue_redraw()


## Starts the particles of `kind` around `origin`, in world pixels. Splinters raise a little
## dust too.
func emit(kind: HitEffect.Kind, origin: Vector2) -> void:
	if kind == HitEffect.Kind.NONE:
		return
	var spec: Dictionary = SPECS[kind]
	var spread: Vector2 = spec["spread"]
	var vertical: Vector2 = spec["vertical"]
	var first_side := _random.randi() % 2
	for i in _random.randi_range(spec["count"].x, spec["count"].y):
		var particle := _new_particle(spec)
		# Outward particles alternate sides, so two drops never fly off the same one.
		var side := 1.0 if (first_side + i) % 2 == 0 else -1.0
		var offset_x := _random.randf_range(-spread.x, spread.x)
		var speed_x := _random.randf_range(-spec["sideways"], spec["sideways"])
		if spec.get("is_outward", false):
			offset_x = side * spread.x
			speed_x = side * _random.randf_range(spec["sideways"] / 2.0, spec["sideways"])
		particle.start = origin + Vector2(offset_x, _random.randf_range(-spread.y, spread.y))
		particle.velocity = Vector2(speed_x, _random.randf_range(vertical.x, vertical.y))
		_particles.append(particle)
	queue_redraw()
	if kind == HitEffect.Kind.SPLINTERS:
		emit(HitEffect.Kind.DUST, origin)


## Starts one particle of `kind` (its colours and sizes, as `emit` picks them) at `origin` that
## flies its own way: at `velocity` (pixels per second), swinging `sway` pixels to the sides and
## `tumble` up and down, for `life` seconds. Leaves blown about the world are these.
func emit_drifting(
	kind: HitEffect.Kind,
	origin: Vector2,
	velocity: Vector2,
	sway: float,
	tumble: float,
	life: float
) -> void:
	var particle := _new_particle(SPECS[kind])
	particle.start = origin
	particle.velocity = velocity
	particle.sway = sway
	particle.tumble = tumble
	particle.life = life
	_particles.append(particle)
	queue_redraw()


## A particle of the spec's look and gravity, sway and life, which the caller sets going.
func _new_particle(spec: Dictionary) -> Particle:
	var colors: Array[Color] = spec["colors"]
	var sizes: Array = spec["sizes"]
	var particle := Particle.new()
	particle.gravity = spec["gravity"]
	particle.sway = spec["sway"]
	particle.phase = _random.randf_range(0.0, TAU)
	particle.life = spec["life"]
	particle.color = colors[_random.randi() % colors.size()]
	particle.size = sizes[_random.randi() % sizes.size()]
	particle.is_shaded = spec["is_shaded"]
	return particle


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
		var shade := color.darkened(SHADE_DARKENING)
		var top_left := particle.position_now().floor()
		var size := Vector2i(particle.size)
		var is_round := size.x >= 3 and size.y >= 3
		for y in size.y:
			for x in size.x:
				var is_edge_x := x == 0 or x == size.x - 1
				var is_edge_y := y == 0 or y == size.y - 1
				if is_round and is_edge_x and is_edge_y:
					continue
				var is_shaded := particle.is_shaded and (x == size.x - 1 or y == size.y - 1)
				draw_rect(
					Rect2(top_left + Vector2(x, y), Vector2.ONE), shade if is_shaded else color
				)
