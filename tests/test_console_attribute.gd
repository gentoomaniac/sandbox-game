extends GutTest
## The console's `attribute` command: sets a level within the rules and says what it gives.


func test_the_command_sets_the_level_and_shows_the_derived_numbers() -> void:
	var state := GameState.new_game(7)
	var console := Console.new(state)
	assert_eq(
		console.run("attribute strength 14"),
		(
			["Strength is 14: 100 energy, 100 health, 56.0 kg carried before it tires you"]
			as Array[String]
		)
	)
	assert_eq(state.player.attributes.level(Attributes.STRENGTH), 14)


func test_the_level_stays_within_the_rules() -> void:
	var state := GameState.new_game(7)
	var console := Console.new(state)
	console.run("attribute stamina 5000")
	assert_eq(state.player.attributes.level(Attributes.STAMINA), 100)
	console.run("attribute stamina 0")
	assert_eq(state.player.attributes.level(Attributes.STAMINA), 1)


func test_the_command_names_an_unknown_attribute_and_wants_a_level() -> void:
	var console := Console.new(GameState.new_game(7))
	assert_eq(console.run("attribute luck 5"), ["Unknown attribute: luck"] as Array[String])
	assert_eq(
		console.run("attribute hp"), ["Usage: attribute <attribute> <level>"] as Array[String]
	)
	assert_eq(
		console.run("attribute hp 1.5"), ["Usage: attribute <attribute> <level>"] as Array[String]
	)


func test_the_attributes_complete() -> void:
	var console := Console.new(GameState.new_game(7))
	assert_eq(console.complete("attribute agi"), "attribute agility ")
