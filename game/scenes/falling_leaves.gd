class_name FallingLeaves
extends Node2D
## Leaves that drop from the trees around the player and blow about in the wind (see
## data/leaf_fall.cfg and LeafFallRules). The world view picks a few tiles around the player at
## random (`tiles_to_look_at`) and offers the trees on them (`shed`): no work per tree or per
## tile every frame, and no more than a fixed number of leaves in the air. View only: nothing
## is saved, and while the player is indoors the world view does not run.

var rules := LeafFallRules.default_rules()
var _leaves := HitParticles.new()
var _random := RandomNumberGenerator.new()
## The fraction of a tile pick that is owed, which carries over from frame to frame.
var _owed_picks := 0.0


func _init() -> void:
	add_child(_leaves)


## The leaves that were in the air when the player went indoors are gone when they come out.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_leaves.clear()


func leaf_count() -> int:
	return _leaves.particle_count()


## The tiles to look at in this frame, `delta` seconds after the last one: random ones around the
## tile the player stands on.
func tiles_to_look_at(delta: float, centre: Vector2i) -> Array[Vector2i]:
	_owed_picks += rules.value("shedding", "tries_per_second") * delta
	var reach := rules.vector("shedding", "radius_tiles")
	var tiles: Array[Vector2i] = []
	while _owed_picks >= 1.0:
		_owed_picks -= 1.0
		var offset := Vector2i(
			_random.randi_range(-int(reach.x), int(reach.x)),
			_random.randi_range(-int(reach.y), int(reach.y))
		)
		tiles.append(centre + offset)
	return tiles


## A tree whose canopy is at `canopy` (world pixels) and whose foliage looks like `look` (what a
## hit on it would throw is `kind`) may shed a leaf on this day, in this wind (m/s),
## `shader_seconds` into the shaders' clock (see AmbientMotion.shader_time). It drops beside the
## tree or, in wind, may be carried off downwind.
func shed(
	kind: HitEffect.Kind,
	look: SeasonBlend.Look,
	day: int,
	canopy: Vector2,
	wind: Vector2,
	shader_seconds := AmbientMotion.shader_time()
) -> void:
	if _leaves.particle_count() >= rules.value("shedding", "max_leaves"):
		return
	var speed := wind.length()
	var gust := (
		AmbientMotion.gust_for(speed)
		* AmbientMotion.gust_front(canopy, wind.normalized(), shader_seconds)
	)
	if _random.randf() >= rules.shed_chance(kind, look, day, speed, gust):
		return
	var spread := rules.vector("fall", "spread")
	var origin := (
		canopy
		+ Vector2(
			_random.randf_range(-spread.x, spread.x), _random.randf_range(-spread.y, spread.y)
		)
	)
	if _random.randf() < rules.carried_chance(speed):
		var fall_speed := rules.vector("carried", "fall_speed")
		var velocity := (
			wind * rules.value("carried", "drift_per_wind")
			+ Vector2(0.0, _random.randf_range(fall_speed.x, fall_speed.y))
		)
		_leaves.emit_drifting(
			kind,
			origin,
			velocity,
			rules.value("carried", "sway"),
			rules.value("carried", "tumble"),
			rules.value("carried", "life")
		)
	else:
		var fall_speed := rules.vector("fall", "fall_speed")
		var sideways := rules.value("fall", "sideways")
		var velocity := Vector2(
			_random.randf_range(-sideways, sideways),
			_random.randf_range(fall_speed.x, fall_speed.y)
		)
		_leaves.emit_drifting(
			kind, origin, velocity, rules.value("fall", "sway"), 0.0, rules.value("fall", "life")
		)
