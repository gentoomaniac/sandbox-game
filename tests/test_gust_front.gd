extends GutTest
## The gust fronts that sweep across the world, as the leaves of the trees see them (the plants'
## shaders have their own copy, see sway.gdshaderinc).


func test_a_gust_front_comes_and_goes_across_the_world() -> void:
	var strongest := 0.0
	var weakest := 1.0
	for step in 40:
		var front := AmbientMotion.gust_front(Vector2(step * 20.0, 0.0), Vector2.RIGHT, 0.0)
		strongest = maxf(strongest, front)
		weakest = minf(weakest, front)
	assert_gt(strongest, 0.95)
	assert_lt(weakest, 0.05)
	assert_almost_eq(
		AmbientMotion.gust_front(Vector2.ZERO, Vector2.RIGHT, 0.0),
		AmbientMotion.gust_front(Vector2(AmbientMotion.GUST_SPEED * 2.0, 0.0), Vector2.RIGHT, 2.0),
		0.001,
		"a front moves downwind at its speed"
	)
