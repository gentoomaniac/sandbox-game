extends GutTest
## The debug flags parsed into typed fields: values, defaults, and what a bad flag does.


func test_no_flags_leave_the_defaults() -> void:
	var options := StartupOptions.new()
	assert_eq(options.at, StartupOptions.NO_TILE)
	assert_eq(options.time_hour, -1)
	assert_eq(options.energy, -1.0)
	assert_eq(options.zoom, ViewMath.MIN_ZOOM)
	assert_eq(options.menu, -1)
	assert_eq(options.screenshot, "")
	assert_false(options.inventory)


func test_flags_with_a_value() -> void:
	var options := (
		StartupOptions
		. new(
			PackedStringArray(
				[
					"--at=40,-20",
					"--day=45",
					"--time=21:30",
					"--energy=15",
					"--weather=rain",
					"--zoom=2",
					"--camera-shift=0.5,-0.25",
					"--screenshot=/tmp/a.png",
					"--screenshot-delay=0.3",
					"--hold=chest",
					"--menu=audio",
					"--tooltip=hotbar_3",
					"--wildlife=bird,flock",
					"--pose=left,2",
					"--hair=1",
					"--riding=pony",
					"--inside=barn",
				]
			)
		)
	)
	assert_eq(options.at, Vector2i(40, -20))
	assert_eq(options.day, 45)
	assert_eq(options.time_hour, 21)
	assert_eq(options.time_minute, 30)
	assert_eq(options.energy, 15.0)
	assert_eq(options.weather, &"rain")
	assert_eq(options.zoom, 2.0)
	assert_eq(options.camera_shift, Vector2(0.5, -0.25))
	assert_eq(options.screenshot, "/tmp/a.png")
	assert_eq(options.screenshot_delay, 0.3)
	assert_eq(options.hold, &"chest")
	assert_eq(options.menu, PauseMenu.Page.AUDIO)
	assert_eq(options.tooltip, "hotbar_3")
	assert_eq(options.wildlife, PackedStringArray(["bird", "flock"]))
	assert_eq(options.pose, "left")
	assert_eq(options.pose_column, 2)
	assert_eq(options.hair, 1)
	assert_eq(options.riding, &"pony")
	assert_true(options.inside)
	assert_eq(options.inside_building, &"barn")


func test_the_building_can_come_with_a_style() -> void:
	var own := StartupOptions.new(PackedStringArray(["--building=kate"]))
	assert_eq([own.building, own.building_style], [&"kate", &""])
	var brick := StartupOptions.new(PackedStringArray(["--building=kate.brick"]))
	assert_eq([brick.building, brick.building_style], [&"kate", &"brick"])


func test_flags_without_a_value() -> void:
	var options := StartupOptions.new(
		PackedStringArray(["--new-game", "--inventory", "--storage", "--inside", "--sleep"])
	)
	assert_true(options.new_game)
	assert_true(options.inventory)
	assert_true(options.storage)
	assert_true(options.inside)
	assert_eq(options.inside_building, &"", "the first house")
	assert_true(options.sleep)
	assert_false(options.crafting)
	assert_false(options.skills)
	var screens := StartupOptions.new(PackedStringArray(["--skills", "--station"]))
	assert_true(screens.skills)
	assert_true(screens.station)


func test_every_tile_flag_reads_its_tile() -> void:
	var options := (
		StartupOptions
		. new(
			PackedStringArray(
				[
					"--mouse-tile=1,2",
					"--ghost=3,4",
					"--house=5,6",
					"--field=7,8",
					"--drops=9,10",
					"--forage=11,12",
					"--felled=13,14",
					"--mow=15,16",
					"--chest=17,18",
					"--chest-inside=19,20",
					"--harvest=21,22",
					"--hit=23,24",
					"--path=25,26",
					"--path-days=3,4",
					"--worn-ground=-12,-7",
				]
			)
		)
	)
	assert_eq(options.mouse_tile, Vector2i(1, 2))
	assert_eq(options.ghost, Vector2i(3, 4))
	assert_eq(options.house, Vector2i(5, 6))
	assert_eq(options.field, Vector2i(7, 8))
	assert_eq(options.drops, Vector2i(9, 10))
	assert_eq(options.forage, Vector2i(11, 12))
	assert_eq(options.felled, Vector2i(13, 14))
	assert_eq(options.mow, Vector2i(15, 16))
	assert_eq(options.chest, Vector2i(17, 18))
	assert_eq(options.chest_inside, Vector2i(19, 20))
	assert_eq(options.harvest, Vector2i(21, 22))
	assert_eq(options.hit, Vector2i(23, 24))
	assert_eq(options.path, Vector2i(25, 26))
	assert_eq(options.path_days, Vector2i(3, 4))
	assert_eq(options.worn_ground, Vector2i(-12, -7))


func test_a_console_line_may_contain_an_equals_sign() -> void:
	var options := StartupOptions.new(PackedStringArray(["--console=speed=2;time 12:00"]))
	assert_eq(options.console, PackedStringArray(["speed=2", "time 12:00"]))


func test_an_unknown_flag_is_ignored_with_a_warning() -> void:
	var options := StartupOptions.new(PackedStringArray(["--no-such-flag", "--day=3"]))
	assert_eq(options.day, 3)


func test_a_malformed_tile_is_an_error_and_leaves_no_tile() -> void:
	var options := StartupOptions.new(PackedStringArray(["--at=40", "--hit=a,b"]))
	assert_push_error_count(2)
	assert_eq(options.at, StartupOptions.NO_TILE)
	assert_eq(options.hit, StartupOptions.NO_TILE)


func test_a_malformed_time_is_an_error_and_leaves_the_time() -> void:
	var options := StartupOptions.new(PackedStringArray(["--time=25:00", "--time=noon"]))
	assert_push_error_count(2)
	assert_eq(options.time_hour, -1)


func test_the_screenshot_size_is_width_by_height() -> void:
	var options := StartupOptions.new(PackedStringArray(["--screenshot-size=1000x1040"]))
	assert_eq(options.screenshot_size, Vector2i(1000, 1040))
	assert_eq(StartupOptions.new(PackedStringArray()).screenshot_size, Vector2i.ZERO)


func test_a_malformed_screenshot_size_is_an_error_and_leaves_no_size() -> void:
	var options := StartupOptions.new(
		PackedStringArray(["--screenshot-size=1000", "--screenshot-size=axb"])
	)
	assert_push_error_count(2)
	assert_eq(options.screenshot_size, Vector2i.ZERO)
