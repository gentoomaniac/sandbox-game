class_name SaveValidator
extends RefCounted
## Checks the game of a save (the `game` of the file, after its upgrades) before anything is
## built from it, so that a damaged save is refused with a message instead of loading half or
## stopping on an assertion. The `from_dict` methods behind it stay strict: they trust what this
## passed.
##
## What it finds is of two kinds:
## - `problems`: the save is damaged (a missing field, a wrong type, a count of -7, a map that
##   is not there). Each says where: "player inventory slot 3: count -7 is not between 1 and 99".
## - `missing`: content the game no longer has (an item, object, tree, recipe or animal that was
##   removed since the save). The save is whole otherwise; `drop_missing` takes those things out
##   of the data, which is the player's choice to make (see LoadResult).
## A save is loadable as it is when both are empty.
##
## The checks themselves are by domain, in game/state/save_checks/, and run in the order of
## `_check_game`: a check that refers to what another found (the buildings of the world) comes
## after it. A new saved feature adds its check to the domain it belongs to, or a domain of its own.

## What the checks found, see SaveContext.
var problems: Array[String]
var missing: Array[String]

var _ctx := SaveContext.new()
var _world := SaveWorldChecks.new(_ctx)
var _player := SavePlayerChecks.new(_ctx)
var _actors := SaveActorChecks.new(_ctx)
var _economy := SaveEconomyChecks.new(_ctx)


func _init() -> void:
	problems = _ctx.problems
	missing = _ctx.missing


static func check(game: Variant) -> SaveValidator:
	var validator := SaveValidator.new()
	validator._check_game(game)
	return validator


## Takes what the game no longer has out of the data that was checked: an item leaves its slot,
## an object, animal or pile goes.
func drop_missing() -> void:
	_ctx.drop_missing()


func _check_game(game: Variant) -> void:
	if not game is Dictionary:
		_ctx.report("", "the game is %s, not a dictionary" % type_string(typeof(game)))
		return
	_world.check_clock(game)
	_world.check_world(game)
	_world.check_explored(game)
	_player.check(game)
	_actors.check_livestock(game)
	_actors.check_npcs(game)
	_economy.check_shops(game)
	_economy.check_quests(game)
	_actors.check_deed_log(game)
	_world.check_map_reference(game, "current_map")
	_world.check_map_reference(game, "home_map")
