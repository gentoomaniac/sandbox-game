extends WildlifeCase
## A sparrow taking off is seen from the front or from behind while it flies mostly down or up
## the screen and side on otherwise (see FlightView).

## Where it flies off to in degrees from east (the screen's y points down, so 90 is down), the
## action it plays and whether it is flipped. The climb of the take-off tilts the direction up.
const CASES := {
	0.0: [FlightView.SIDE, false],
	180.0: [FlightView.SIDE, true],
	90.0: [FlightView.FRONT, false],
	270.0: [FlightView.BACK, false],
	110.0: [FlightView.FRONT, false],
}


func test_a_sparrow_flies_off_in_the_view_of_its_direction() -> void:
	for degrees: float in CASES:
		var bird := Bird.new()
		_wildlife._add(bird, true)
		bird._take_off(Vector2.RIGHT.rotated(deg_to_rad(degrees)))
		_run(bird, 0.5)
		assert_eq(bird._action, CASES[degrees][0], "%s degrees" % degrees)
		assert_eq(bird._sprite.flip_h, CASES[degrees][1], "%s degrees" % degrees)
		var first := WildlifeSprites.frame_index(&"bird", CASES[degrees][0], 0)
		var frames := WildlifeSprites.frame_count(&"bird", CASES[degrees][0])
		assert_between(bird._sprite.frame, first, first + frames - 1, "%s degrees" % degrees)
