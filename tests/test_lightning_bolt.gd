extends GutTest
## The bolt of a close strike: a jagged main channel from the top of the view with branches
## forking off it, the same for the same seed.

const SIZE := Vector2i(644, 364)

var _rules := WeatherRules.default_rules()


func _bolt(shape_seed: int) -> LightningBolt:
	return LightningBolt.new(shape_seed, SIZE, _rules)


func test_the_main_channel_runs_down_from_the_top_of_the_view() -> void:
	var main := _bolt(1).paths[LightningBolt.MAIN]
	assert_eq(main[0].y, 0.0)
	assert_gt(main[-1].y, SIZE.y * _rules.value("bolt", "reach_min_share") * 0.9)
	var is_jagged := false
	for index in range(2, main.size()):
		if not is_equal_approx(main[index].x - main[index - 1].x, main[1].x - main[0].x):
			is_jagged = true
	assert_true(is_jagged, "it is not a straight line")


func test_every_bolt_forks_into_at_least_the_least_number_of_branches() -> void:
	for shape_seed in 50:
		var bolt := _bolt(shape_seed)
		var branches := bolt.depths.filter(func(depth: int) -> bool: return depth > 0).size()
		assert_gte(branches, int(_rules.value("bolt", "branches_min")), "seed %d" % shape_seed)


func test_branches_fork_off_the_channel_they_belong_to_and_go_down() -> void:
	var bolt := _bolt(3)
	for index in range(1, bolt.paths.size()):
		var path := bolt.paths[index]
		assert_gt(path[-1].y, path[0].y, "branch %d goes down" % index)
		assert_gt(bolt.depths[index], 0)


func test_the_same_seed_gives_the_same_bolt_and_another_seed_another() -> void:
	assert_eq(_bolt(7).paths, _bolt(7).paths)
	assert_ne(_bolt(7).paths, _bolt(8).paths)
