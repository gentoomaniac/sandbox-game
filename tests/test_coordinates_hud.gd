extends GutTest
## The F3 overlay: the tile, the weather, and at the bottom the frames per second.


func test_the_text_ends_with_the_frames_per_second() -> void:
	var text := CoordinatesHud.text_of(Vector2i(12, -3), false, "Sunny", 60)
	assert_eq(text, "12, -3\nSunny\n60 fps")


func test_inside_a_house_the_room_is_marked() -> void:
	var text := CoordinatesHud.text_of(Vector2i(2, 5), true, "Rain", 240)
	assert_eq(text, "House 2, 5\nRain\n240 fps")
