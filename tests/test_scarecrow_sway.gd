extends GutTest
## The scarecrow in the wind (task 226): still in calm weather, else going through its pictures,
## quicker as the wind rises.


func test_it_stands_still_in_calm_weather() -> void:
	var motion := AmbientMotion.new()
	for _i in 100:
		motion.update(0.1, Vector2(AmbientMotion.SCARECROW_CALM_WIND - 0.1, 0.0), 0.0)
		assert_eq(motion.scarecrow_frame(), 0)


func test_in_wind_it_goes_through_all_its_pictures_and_back() -> void:
	var motion := AmbientMotion.new()
	var seen := []
	for _i in 200:
		motion.update(0.1, Vector2(5.0, 0.0), 0.0)
		if seen.is_empty() or seen[-1] != motion.scarecrow_frame():
			seen.append(motion.scarecrow_frame())
	assert_eq(seen.slice(0, 8), [0, 1, 2, 1, 0, 1, 2, 1])


func test_a_stronger_wind_moves_it_faster() -> void:
	var changes := {}
	for speed in [3.0, 12.0]:
		var motion := AmbientMotion.new()
		var last := -1
		changes[speed] = 0
		for _tick in 1000:
			motion.update(0.05, Vector2(speed, 0.0), 0.0)
			changes[speed] += int(motion.scarecrow_frame() != last)
			last = motion.scarecrow_frame()
	assert_gt(changes[12.0], changes[3.0])


func test_a_wind_that_keeps_changing_never_makes_it_jump() -> void:
	var motion := AmbientMotion.new()
	var last := 0
	for tick in 20000:
		var speed := 8.0 + 5.0 * sin(tick * 0.01)
		motion.update(0.02, Vector2(speed, 0.0), 0.0)
		var frame := motion.scarecrow_frame()
		# One step of the cycle 0-1-2-1 at most: the neighbouring frame or the same one.
		assert_true(
			frame == last or frame == 1 or last == 1, "%d to %d at %d" % [last, frame, tick]
		)
		last = frame


func test_the_object_atlas_cell_is_the_frame_asked_for() -> void:
	var scarecrow := WorldObject.new(WorldObjectTypes.SCARECROW, Vector2i(3, 4))
	var row: int = scarecrow.type_data()["atlas_row"]
	for frame in 3:
		assert_eq(ObjectTileset.atlas_cell(scarecrow, false, 0, frame), Vector2i(frame, row))
	assert_eq(ObjectTileset.looks_count(scarecrow.type_data()), 3)
