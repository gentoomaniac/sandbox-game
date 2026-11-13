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
	var known := sheet.topic_names()
	assert_eq(sheet.text(true, known), "Places: The church. The mill.\nMoney: Butter is dear.")
	assert_eq(sheet.text(false, known), "Money: Dear.", "a topic without a cut-down is left out")


func test_only_the_known_topics_are_told() -> void:
	var sheet := VillageSheet.default_sheet()
	var known: Array[String] = ["money"]

	var told := sheet.text(true, known)

	assert_string_starts_with(told, "Money and prices: ")
	assert_false(told.contains("\n"), "one topic, one line")
	assert_eq(sheet.text(true, [] as Array[String]), "")


func test_the_topics_are_told_in_the_order_of_the_file() -> void:
	# DataFile keeps the sections in the order of the file (ConfigFile lists them so, and a
	# Dictionary keeps the order its keys were added in).
	var sheet := VillageSheet.default_sheet()
	var titles := Array(sheet.text(true, sheet.topic_names()).split("\n")).map(
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
	var known := sheet.topic_names()
	assert_lt(sheet.text(false, known).length() * 3, sheet.text(true, known).length())
	assert_string_contains(sheet.text(false, known), "Johann Martens")
	assert_string_contains(sheet.text(true, known), "Johann Martens")


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
