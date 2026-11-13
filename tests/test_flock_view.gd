extends WildlifeCase
## The birds of a flock in the sky are seen side on while it flies across the view, flipped when
## it flies left, and from the front or from behind while it flies mostly down or up it.

## Headings around the compass in degrees from east (the screen's y points down, so 90 is down
## the screen, south) and the view each shows.
const VIEWS := {
	0.0: Flock.SIDE_VIEW,
	30.0: Flock.SIDE_VIEW,
	50.0: Flock.FRONT_VIEW,
	90.0: Flock.FRONT_VIEW,
	130.0: Flock.FRONT_VIEW,
	150.0: Flock.SIDE_VIEW,
	180.0: Flock.SIDE_VIEW,
	210.0: Flock.SIDE_VIEW,
	230.0: Flock.BACK_VIEW,
	270.0: Flock.BACK_VIEW,
	310.0: Flock.BACK_VIEW,
	330.0: Flock.SIDE_VIEW,
}
## Half a degree either side of each boundary (45 degrees from the vertical, see
## Flock.HEAD_ON_DEGREES) and the view on that side.
const BOUNDARIES := {
	44.5: Flock.SIDE_VIEW,
	45.5: Flock.FRONT_VIEW,
	134.5: Flock.FRONT_VIEW,
	135.5: Flock.SIDE_VIEW,
	224.5: Flock.SIDE_VIEW,
	225.5: Flock.BACK_VIEW,
	314.5: Flock.BACK_VIEW,
	315.5: Flock.SIDE_VIEW,
}


func test_the_view_follows_the_heading_around_the_compass() -> void:
	for degrees: float in VIEWS:
		var heading := Vector2.RIGHT.rotated(deg_to_rad(degrees))
		assert_eq(Flock.view_of(heading), VIEWS[degrees], "heading %s degrees" % degrees)


func test_the_view_changes_45_degrees_from_the_vertical() -> void:
	for degrees: float in BOUNDARIES:
		var heading := Vector2.RIGHT.rotated(deg_to_rad(degrees))
		assert_eq(Flock.view_of(heading), BOUNDARIES[degrees], "heading %s degrees" % degrees)


func test_migrating_flocks_within_the_spread_are_seen_head_on() -> void:
	for kind in [WildlifeRules.FLOCK, WildlifeRules.FLYING_GEESE]:
		var spread := deg_to_rad(float(_wildlife.rules._value(kind, "migration_spread_degrees")))
		for side in [-1.0, 1.0]:
			assert_eq(Flock.view_of(Vector2.DOWN.rotated(spread * side)), Flock.FRONT_VIEW)
			assert_eq(Flock.view_of(Vector2.UP.rotated(spread * side)), Flock.BACK_VIEW)


func test_the_birds_show_the_frames_of_their_view() -> void:
	var cases := {
		Vector2.DOWN: [Flock.FRONT_VIEW, false],
		Vector2.UP: [Flock.BACK_VIEW, false],
		Vector2.RIGHT: [Flock.SIDE_VIEW, false],
		Vector2.LEFT: [Flock.SIDE_VIEW, true],
	}
	for kind in [WildlifeRules.FLOCK, WildlifeRules.FLYING_GEESE]:
		for heading: Vector2 in cases:
			var flock := Flock.new(kind)
			flock.set_course(VIEW_CENTRE, VIEW_CENTRE + heading * 1000.0, 5)
			_wildlife._add(flock, true)
			_run(flock, 1.0)
			var sheet: StringName = Flock.BIRDS[kind]["sheet"]
			var view: StringName = cases[heading][0]
			var row := WildlifeSprites.frame_index(sheet, view, 0)
			for bird in flock._birds:
				assert_between(bird.frame, row, row + WildlifeSprites.frame_count(sheet, view) - 1)
				assert_eq(bird.flip_h, cases[heading][1], "%s heading %s" % [kind, heading])
