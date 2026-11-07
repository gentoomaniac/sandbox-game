extends GutTest
## The village every villager knows (data/village.cfg): told in full to a hosted model and cut
## down to a local one.


func test_the_data_file_is_valid() -> void:
	var sheet := VillageSheet.default_sheet()
	assert_true(sheet.is_valid(), "problems: %s" % [sheet.problems()])


func test_the_full_sheet_has_a_line_per_topic_with_its_title() -> void:
	var sheet := (
		VillageSheet
		. new(
			{
				"places": {"title": "Places", "full": ["The church.", "The mill."], "short": []},
				"money": {"title": "Money", "full": ["Butter is dear."], "short": ["Dear."]},
			}
		)
	)
	assert_eq(sheet.text(true), "Places: The church. The mill.\nMoney: Butter is dear.")
	assert_eq(sheet.text(false), "Money: Dear.", "a topic without a cut-down is left out")


func test_the_topics_are_told_in_the_order_of_the_file() -> void:
	# DataFile keeps the sections in the order of the file (ConfigFile lists them so, and a
	# Dictionary keeps the order its keys were added in).
	var titles := Array(VillageSheet.default_sheet().text(true).split("\n")).map(
		func(line: String) -> String: return line.get_slice(":", 0)
	)
	assert_eq(
		titles,
		[
			"The village",
			"Places",
			"Who is who",
			"Money and prices",
			"This year's news and worries",
			"The year",
			"What people know of the world",
		]
	)


func test_the_cut_down_sheet_is_much_shorter_and_names_the_pastor() -> void:
	var sheet := VillageSheet.default_sheet()
	assert_lt(sheet.text(false).length() * 3, sheet.text(true).length())
	assert_string_contains(sheet.text(false), "Johann Martens")
	assert_string_contains(sheet.text(true), "Johann Martens")


func test_what_is_missing_or_wrong_is_reported() -> void:
	var sheet := VillageSheet.new({"places": {"full": [], "short": "the church"}})
	assert_eq(
		sheet.problems(),
		(
			[
				"[places] title is not a text",
				"[places] full is not a list of at least one text",
				"[places] short is not a list of texts",
			]
			as Array[String]
		)
	)
	assert_eq(VillageSheet.new({}).problems(), ["no topics"] as Array[String])


func test_a_missing_file_is_reported() -> void:
	var sheet := VillageSheet.from_file("res://data/no_such_file.cfg")
	assert_push_error_count(2)
	assert_false(sheet.is_valid())
