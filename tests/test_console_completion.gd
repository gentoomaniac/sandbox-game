extends EnergyCase
## Tab completion in the console.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func test_complete_a_command_name() -> void:
	assert_eq(_console.complete("gi"), "give ")
	assert_eq(_console.complete("/no"), "/no")
	assert_eq(_console.complete("/nod"), "/nodrain ")


func test_complete_goes_as_far_as_the_candidates_agree() -> void:
	assert_eq(_console.complete("n"), "no")


func test_complete_an_item_after_give() -> void:
	assert_eq(_console.complete("give tur"), "give turnip")
	assert_eq(_console.complete("give ston"), "give stone ")
	assert_eq(_console.complete("/give pick"), "/give pickaxe ")


func test_complete_leaves_other_words_alone() -> void:
	assert_eq(_console.complete("give logs 5"), "give logs 5")
	assert_eq(_console.complete("tp 1"), "tp 1")
	assert_eq(_console.complete("give zzz"), "give zzz")


func test_complete_the_ids_of_the_crop_items() -> void:
	assert_eq(_console.complete("give carrot_s"), "give carrot_seeds ")
	assert_eq(_console.complete("give potato_"), "give potato_seeds ")
	assert_eq(_console.complete("give pump"), "give pumpkin")
	assert_eq(_console.complete("give flax_"), "give flax_seeds ")
	assert_eq(_console.complete("give whe"), "give wheat")
	assert_eq(_console.complete("give bea"), "give beans")


func test_every_crop_item_is_a_candidate_after_give() -> void:
	for crop_id in CropRules.default_rules().crop_ids():
		var seeds: StringName = WorldObjectTypes.TYPES[crop_id]["seed"]
		assert_true(ItemTypes.TYPES.has(seeds))
		assert_eq(_console.complete("give %s" % seeds), "give %s " % seeds, str(seeds))


func test_complete_the_arguments_of_every_command() -> void:
	assert_eq(_console.complete("spawn sq"), "spawn squirrel ")
	assert_eq(_console.complete("weather fo"), "weather fog ")
	assert_eq(_console.complete("snow a"), "snow auto ")
	assert_eq(_console.complete("snow 0"), "snow 0")
	assert_eq(_console.complete("snow 0."), "snow 0.5 ")


func test_numbers_and_extra_words_complete_nothing() -> void:
	assert_eq(_console.complete("tp "), "tp ")
	assert_eq(_console.complete("spawn deer "), "spawn deer ")
	assert_eq(_console.complete("weather fog f"), "weather fog f")
	assert_eq(_console.complete("god g"), "god g")


func test_the_argument_table_names_real_commands_and_kinds() -> void:
	for command: String in Console.ARGUMENTS:
		assert_true(Console.COMMANDS.has(command), command)
		for kind: StringName in Console.ARGUMENTS[command]:
			var has_candidates := not _console.candidates(kind).is_empty()
			assert_eq(has_candidates, kind != &"number", "%s %s" % [command, kind])
