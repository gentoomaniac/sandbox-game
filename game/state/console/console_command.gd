class_name ConsoleCommand
extends RefCounted
## What every console command is: its name and texts, the kinds of its arguments (for Tab) and what
## it does. One command is one script in game/state/console/commands/ that extends this; the
## console (see ConsoleLoader) loads them all, so a new command is a new file there.

## What the command works on and asks of the game scene; never the console itself.
var context: ConsoleContext


func _init(console_context: ConsoleContext) -> void:
	context = console_context


## The word that runs the command.
func name() -> String:
	return ""


## How the command is typed, e.g. "give <item> [count]".
func usage() -> String:
	return ""


## What the command does, in a sentence or two.
func help() -> String:
	return ""


## The kind of each argument, in order, for Tab completion and for the names `help <command>`
## lists (see ConsoleHelper.candidates). Numbers have no candidates; no arguments is the default.
func argument_kinds() -> Array[StringName]:
	return []


## The kinds when the arguments typed so far are `arguments`: for a command whose later arguments
## depend on the first one.
func argument_kinds_for(_arguments: PackedStringArray) -> Array[StringName]:
	return argument_kinds()


## Whether the first argument may also be the id of a villager (Tab offers those, and `help` lists
## them after the other kinds).
func takes_villager_ids() -> bool:
	return false


## Runs the command with the words after its name and returns the lines to show.
func run(_arguments: PackedStringArray) -> Array[String]:
	return []


## The answer to a wrong use of the command.
func wrong_usage() -> Array[String]:
	return ["Usage: %s" % usage()]
