extends GutTest
## How the sails of a windmill turn (SailTurn).


func test_still_sails_show_the_first_frame_and_stay() -> void:
	var turn := SailTurn.new()
	turn.step(10.0)
	assert_true(turn.is_still())
	assert_eq(turn.frame(), 0)


func test_the_sails_go_through_the_frames_and_loop() -> void:
	var turn := SailTurn.new()
	turn.speed = 1.0
	var seen: Array[int] = []
	for second in SailTurn.FRAMES:
		turn.step(1.0 / SailTurn.FRAMES_PER_SECOND)
		seen.append(turn.frame())
	assert_eq(seen, [1, 2, 3, 4, 5, 6, 7, 0] as Array[int])


func test_faster_wind_turns_the_sails_through_more_frames() -> void:
	var slow := SailTurn.new()
	var fast := SailTurn.new()
	slow.speed = 0.5
	fast.speed = 2.0
	slow.step(0.5)
	fast.step(0.5)
	assert_lt(slow.frame(), fast.frame())
