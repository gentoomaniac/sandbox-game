class_name ConsoleLoader
extends RefCounted
## Finds the scripts of the console's commands and makes one command of each. A script that does not
## load, is no command, or has no name or one that another has, is a problem for the console to
## report loudly, not one to skip silently.

const COMMANDS_DIR := "res://game/state/console/commands"
const SCRIPT_SUFFIX := ".gd"


## The paths of the scripts in `directory`, by name. `ResourceLoader` lists the resources, so this
## works in an exported game too; folders and any files that are no scripts are left out.
static func script_paths(directory := COMMANDS_DIR) -> Array[String]:
	var paths: Array[String] = []
	for file in ResourceLoader.list_directory(directory):
		if file.ends_with(SCRIPT_SUFFIX):
			paths.append(directory.path_join(file))
	paths.sort()
	return paths


## One command from each script in `paths`. What is wrong with a script is added to `problems`,
## and that script gives no command.
static func load_commands(
	paths: Array[String], context: ConsoleContext, problems: Array[String]
) -> Array[ConsoleCommand]:
	var commands: Array[ConsoleCommand] = []
	var owners := {}  # name -> path of the script that has it
	for path in paths:
		var resource: Resource = load(path) if ResourceLoader.exists(path) else null
		if resource == null:
			problems.append("%s cannot be loaded" % path)
			continue
		var script := resource as GDScript
		if script == null or not _extends_command(script):
			problems.append("%s is no script that extends ConsoleCommand" % path)
			continue
		var command: ConsoleCommand = script.new(context)
		if command.name().is_empty():
			problems.append("%s has no name" % path)
		elif owners.has(command.name()):
			problems.append(
				"%s: %s is also the name of %s" % [path, command.name(), owners[command.name()]]
			)
		else:
			owners[command.name()] = path
			commands.append(command)
	return commands


static func _extends_command(script: GDScript) -> bool:
	var base := script.get_base_script()
	while base != null:
		if base == ConsoleCommand:
			return true
		base = base.get_base_script()
	return false
