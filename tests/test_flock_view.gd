extends WildlifeCase
## The birds of a flock in the sky are seen side on while it flies across the view, flipped when
## it flies left, and from the front or from behind while it flies mostly down or up it.

## Headings around the compass in degrees from east (the screen's y points down, so 90 is down
## the screen, south) and the view each shows.
const VIEWS := {
	0.0: FlightView.SIDE,
	30.0: FlightView.SIDE,
	50.0: FlightView.FRONT,
	90.0: FlightView.FRONT,
	130.0: FlightView.FRONT,
	150.0: FlightView.SIDE,
	180.0: FlightView.SIDE,
	210.0: FlightView.SIDE,
	230.0: FlightView.BACK,
	270.0: FlightView.BACK,
	310.0: FlightView.BACK,
	330.0: FlightView.SIDE,
}
## Half a degree either side of each boundary (45 degrees from the vertical, see
## FlightView.HEAD_ON_DEGREES) and the view on that side.
const BOUNDARIES := {
	44.5: FlightView.SIDE,
	45.5: FlightView.FRONT,
	134.5: FlightView.FRONT,
	135.5: FlightView.SIDE,
	224.5: FlightView.SIDE,
	225.5: FlightView.BACK,
	314.5: FlightView.BACK,
	315.5: FlightView.SIDE,
}


func test_the_view_follows_the_heading_around_the_compass() -> void:
	for degrees: float in VIEWS:
		var heading := Vector2.RIGHT.rotated(deg_to_rad(degrees))
		assert_eq(FlightView.of(heading), VIEWS[degrees], "heading %s degrees" % degrees)


func test_the_view_changes_45_degrees_from_the_vertical() -> void:
	for degrees: float in BOUNDARIES:
		var heading := Vector2.RIGHT.rotated(deg_to_rad(degrees))
		assert_eq(FlightView.of(heading), BOUNDARIES[degrees], "heading %s degrees" % degrees)


func test_migrating_flocks_within_the_spread_are_seen_head_on() -> void:
	for kind in [WildlifeRules.FLOCK, WildlifeRules.FLYING_GEESE]:
		var spread := deg_to_rad(float(_wildlife.rules._value(kind, "migration_spread_degrees")))
		for side in [-1.0, 1.0]:
			assert_eq(FlightView.of(Vector2.DOWN.rotated(spread * side)), FlightView.FRONT)
			assert_eq(FlightView.of(Vector2.UP.rotated(spread * side)), FlightView.BACK)


func test_the_birds_show_the_frames_of_their_view() -> void:
	var cases := {
		Vector2.DOWN: [FlightView.FRONT, false],
		Vector2.UP: [FlightView.BACK, false],
		Vector2.RIGHT: [FlightView.SIDE, false],
		Vector2.LEFT: [FlightView.SIDE, true],
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


## The widest the bird is in any frame of a view, in the sheet's pixels.
func _widest(sheet: StringName, view: StringName) -> int:
	var image := WildlifeSprites.sheet_texture(sheet).get_image()
	var size: Vector2i = WildlifeSprites.SHEETS[sheet]["size"]
	var cell := Vector2i(image.get_width() / WildlifeSprites.max_frames(sheet), 0)
	cell.y = image.get_height() / WildlifeSprites.SHEETS[sheet]["actions"].size()
	var scale := size.x / float(cell.x)
	var widest := 0
	for column in WildlifeSprites.frame_count(sheet, view):
		var frame := WildlifeSprites.frame_index(sheet, view, column)
		var at := Vector2i(frame % WildlifeSprites.max_frames(sheet), 0) * cell.x
		at.y = frame / WildlifeSprites.max_frames(sheet) * cell.y
		var used := image.get_region(Rect2i(at, cell)).get_used_rect()
		widest = maxi(widest, ceili(used.size.x * scale))
	return widest


func test_head_on_the_spread_wings_of_neighbours_clear_each_other() -> void:
	for kind in [WildlifeRules.FLOCK, WildlifeRules.FLYING_GEESE]:
		var sheet: StringName = Flock.BIRDS[kind]["sheet"]
		for heading: Vector2 in [Vector2.DOWN, Vector2.UP]:
			var wingspan := _widest(sheet, FlightView.of(heading))
			var flock := Flock.new(kind)
			autofree(flock)
			flock.set_course(VIEW_CENTRE, VIEW_CENTRE + heading * 1000.0, 7)
			var side := heading.rotated(PI / 2.0)
			# Each bird behind the leader and the one ahead of it on its side of the V.
			for i in range(1, flock._offsets.size()):
				var ahead := 0 if i <= 2 else i - 2
				var apart := absf((flock._offsets[i] - flock._offsets[ahead]).dot(side))
				assert_gt(apart, float(wingspan), "%s heading %s, bird %d" % [kind, heading, i])


func test_side_on_the_v_keeps_its_spacing() -> void:
	var flock := Flock.new(WildlifeRules.FLOCK)
	autofree(flock)
	flock.set_course(VIEW_CENTRE, VIEW_CENTRE + Vector2.RIGHT * 1000.0, 3)
	var spacing: Vector2 = Flock.BIRDS[WildlifeRules.FLOCK]["spacing"]
	assert_eq(flock._offsets, Flock.v_offsets(Vector2.RIGHT, 3, spacing))
