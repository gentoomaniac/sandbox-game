extends GutTest
## The console loads its commands from the files of game/state/console/commands/.

const RESET_SCRIPT := "res://game/state/console/commands/reset_command.gd"

var _context: ConsoleContext


func before_each() -> void:
	_context = ConsoleContext.new(GameFactory.new_game(1))


func test_every_file_loads_as_a_command_with_its_texts() -> void:
	var problems: Array[String] = []
	var paths := ConsoleLoader.script_paths()
	var commands := ConsoleLoader.load_commands(paths, _context, problems)
	assert_eq(problems, [] as Array[String])
	assert_eq(commands.size(), paths.size())
	for command in commands:
		assert_false(command.name().is_empty(), command.get_script().resource_path)
		assert_false(command.usage().is_empty(), command.name())
		assert_false(command.help().is_empty(), command.name())
		assert_true(command.usage().begins_with(command.name()), command.name())


func test_the_console_loads_all_of_them_and_help_lists_each() -> void:
	var console := Console.new(_context.state)
	var text := "\n".join(console.run("help"))
	assert_eq(console.context.commands.size(), ConsoleLoader.script_paths().size())
	for command in console.context.commands:
		assert_string_contains(text, command.usage())


func test_a_name_twice_is_reported() -> void:
	var problems: Array[String] = []
	var paths: Array[String] = [RESET_SCRIPT, RESET_SCRIPT]
	var commands := ConsoleLoader.load_commands(paths, _context, problems)
	assert_eq(commands.size(), 1)
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "reset")


func test_a_script_that_is_no_command_is_reported() -> void:
	var problems: Array[String] = []
	var paths: Array[String] = ["res://game/state/console/console_context.gd"]
	assert_true(ConsoleLoader.load_commands(paths, _context, problems).is_empty())
	assert_string_contains(problems[0], "ConsoleCommand")


func test_a_script_with_no_name_is_reported() -> void:
	var problems: Array[String] = []
	var paths: Array[String] = ["res://tests/console_unnamed_command.gd"]
	assert_true(ConsoleLoader.load_commands(paths, _context, problems).is_empty())
	assert_string_contains(problems[0], "has no name")


func test_a_script_that_does_not_load_is_reported() -> void:
	var problems: Array[String] = []
	var paths: Array[String] = ["res://game/state/console/commands/missing_command.gd"]
	assert_true(ConsoleLoader.load_commands(paths, _context, problems).is_empty())
	assert_string_contains(problems[0], "cannot be loaded")


func test_the_scan_takes_the_scripts_of_the_folder_by_name() -> void:
	var paths := ConsoleLoader.script_paths()
	assert_has(paths, RESET_SCRIPT)
	for path in paths:
		assert_true(path.ends_with(".gd"), path)
