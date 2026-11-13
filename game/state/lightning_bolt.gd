class_name LightningBolt
extends RefCounted
## The bolt of a close strike, drawn in the sky for the few frames of its flash: a main channel
## that jags down from the top of the view, with branches that fork off it and thinner ones off
## those, like a tree upside down. It is made once per strike from the strike's seed, in art
## pixels: only the geometry, which BoltImage draws. The numbers are in data/weather.cfg's [bolt].

## The depth of the main channel; a branch of it is 1 and a branch of that 2.
const MAIN := 0
## Every channel as a polyline of art pixels, the main one first.
var paths: Array[PackedVector2Array] = []
## The depth of each channel in `paths`.
var depths: Array[int] = []
var _dice := RandomNumberGenerator.new()
var _rules: WeatherRules


## The bolt of a strike, in a view of `size` art pixels.
func _init(shape_seed: int, size: Vector2i, rules := WeatherRules.default_rules()) -> void:
	_rules = rules
	_dice.seed = shape_seed
	var start := Vector2(size.x * _dice.randf_range(0.25, 0.75), 0.0)
	var reach := size.y * _dice.randf_range(_value("reach_min_share"), _value("reach_max_share"))
	_add_channel(start, Vector2.DOWN, reach, MAIN)
	var main := paths[MAIN]
	var forks := range(1, main.size())
	var fork_count := _dice.randi_range(
		int(_value("branches_min")), mini(int(_value("branches_max")), forks.size())
	)
	for _i in fork_count:
		var vertex: int = forks.pop_at(_dice.randi() % forks.size())
		_add_branch(main[vertex], reach * _value("branch_length_share"), 1)


func _value(key: String) -> float:
	return _rules.value("bolt", key)


## A branch off `from`, leaning to a random side, with a branch of its own now and then.
func _add_branch(from: Vector2, length: float, depth: int) -> void:
	var lean := _dice.randf_range(0.5, 1.1) * (1.0 if _dice.randf() < 0.5 else -1.0)
	_add_channel(from, Vector2(lean, 1.0).normalized(), length * _dice.randf_range(0.6, 1.0), depth)
	if depth < 2 and _dice.randf() < _value("sub_branch_chance"):
		var branch := paths[-1]
		_add_branch(branch[_dice.randi_range(1, branch.size() - 1)], length * 0.5, depth + 1)


## A polyline from `from` along `heading`, in jagged steps of the configured length, sideways
## off the heading by up to the configured jag each.
func _add_channel(from: Vector2, heading: Vector2, length: float, depth: int) -> void:
	var side := Vector2(-heading.y, heading.x)
	var path := PackedVector2Array([from])
	var travelled := 0.0
	while travelled < length:
		var step := _dice.randf_range(_value("step_min_px"), _value("step_max_px"))
		var jag := _dice.randf_range(-_value("jag_px"), _value("jag_px"))
		path.append(path[-1] + heading * step + side * jag)
		travelled += step
	paths.append(path)
	depths.append(depth)
