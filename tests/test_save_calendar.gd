extends SaveUpgradeCase
## Version 43 had seasons of 30 days (#85): an old save keeps its year, season and day of the
## season, with every day and minute it holds moved the same way.

const MINUTES_PER_DAY := GameClock.MINUTES_PER_DAY


func test_a_version_43_save_stays_in_its_season() -> void:
	var game := _current_game()
	game["clock"]["day"] = 130
	_write_save(43, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.clock.date_text(), "10th day of Spring Year 2")
	assert_eq(restored.clock.day, 150)


func test_a_current_save_keeps_its_day() -> void:
	var state := GameState.new_game(7)
	state.clock.day = 130
	assert_true(SaveFile.write(state, SAVE_PATH))

	assert_eq(SaveFile.read(SAVE_PATH).clock.day, 130)


func test_the_days_at_the_edges_of_seasons_and_years_keep_their_place() -> void:
	var expected := {
		1: 1,
		30: 30,
		31: 36,
		60: 65,
		61: 71,
		90: 100,
		91: 106,
		120: 135,
		121: 141,
		150: 170,
		151: 176,
		241: 281,
	}
	for old_day: int in expected:
		var game := {"clock": {"day": old_day, "minute_of_day": 360}}
		SaveFile._upgrade_from_version_43(game)
		assert_eq(game["clock"]["day"], expected[old_day], "day %d" % old_day)
		assert_eq(game["clock"]["minute_of_day"], 360, "the time of day stays")


func test_the_season_of_every_old_day_is_kept() -> void:
	for old_day in range(1, 481):
		var old_season := ((old_day - 1) % 120) / 30
		var old_day_of_season := (old_day - 1) % 30 + 1
		var game := {"clock": {"day": old_day}}
		SaveFile._upgrade_from_version_43(game)
		var new_day: int = game["clock"]["day"]
		assert_eq(GameClock.season_of(new_day), old_season, "season of day %d" % old_day)
		assert_eq(GameClock.day_of_season_of(new_day), old_day_of_season, "day %d" % old_day)
		assert_eq(GameClock.year_of(new_day), (old_day - 1) / 120 + 1, "year of day %d" % old_day)


func test_the_days_and_minutes_a_save_counts_from_move_with_the_clock() -> void:
	# Old day 31 is the first of summer: day 36 now.
	var summer_minute := 30 * MINUTES_PER_DAY + 100
	var game := {
		"clock": {"day": 61, "minute_of_day": 0},
		"deeds": [{"day": 31, "minute": 100, "count": 1, "kind": "felled", "place": "here"}],
		"livestock": [{"follow_until_minute": summer_minute, "last_petted_day": 31}],
		"npcs":
		[
			{
				"day": "Out in the fields all day.",
				"opinion_day": 0,
				"chat_history": [{"day": 31, "minute": 5, "text": "Moin"}],
				"memories": [{"day": 0, "text": "Unknown day"}, {"day": 31, "text": "Summer"}],
				"stories":
				[
					{
						"day": 31,
						"learned_at": summer_minute,
						"origin": "31|felled|here",
					}
				],
			}
		],
		"world":
		{
			"object_edits":
			[
				{
					"state":
					{"placed_day": 61, "run": {"start_minute": 0, "done_minute": summer_minute}}
				}
			]
		},
	}

	SaveFile._upgrade_from_version_43(game)

	var new_summer_minute := 35 * MINUTES_PER_DAY + 100
	assert_eq(game["clock"]["day"], 71)
	assert_eq(game["deeds"][0]["day"], 36)
	assert_eq(game["deeds"][0]["minute"], 100, "a minute of the day stays")
	assert_eq(game["livestock"][0]["follow_until_minute"], new_summer_minute)
	assert_eq(game["livestock"][0]["last_petted_day"], 36)
	var npc: Dictionary = game["npcs"][0]
	assert_eq(npc["day"], "Out in the fields all day.", "the words of the villager's day stay")
	assert_eq(npc["opinion_day"], 0, "day 0 is never")
	assert_eq(npc["chat_history"][0]["day"], 36)
	assert_eq([npc["memories"][0]["day"], npc["memories"][1]["day"]], [0, 36])
	assert_eq(npc["stories"][0]["day"], 36)
	assert_eq(npc["stories"][0]["learned_at"], new_summer_minute)
	assert_eq(npc["stories"][0]["origin"], "36|felled|here")
	var state: Dictionary = game["world"]["object_edits"][0]["state"]
	assert_eq(state["placed_day"], 71)
	assert_eq([state["run"]["start_minute"], state["run"]["done_minute"]], [0, new_summer_minute])
