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

## What the checks found, see SaveContext.
var problems: Array[String]
var missing: Array[String]

var _ctx := SaveContext.new()
var _world := SaveWorldChecks.new(_ctx)
var _player := SavePlayerChecks.new(_ctx)
var _actors := SaveActorChecks.new(_ctx)


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
	_check_shops(game)
	_check_quests(game)
	_actors.check_deed_log(game)
	_world.check_map_reference(game, "current_map")
	_world.check_map_reference(game, "home_map")


## The quests: those posted or taken, each with its id, giver, the day it was posted and whether it
## is taken, and the day each quest that was done and each that ended was last seen.
func _check_quests(game: Dictionary) -> void:
	var quests: Variant = _ctx.field(game, "quests", SaveContext.Kind.DICT, "")
	if quests == null:
		return
	var open: Variant = _ctx.field(quests, "open", SaveContext.Kind.LIST, "quests")
	for index in [] if open == null else open.size():
		var path := "quests open %d" % index
		var entry: Variant = open[index]
		if not entry is Dictionary:
			_ctx.report(path, "should be a dictionary")
			continue
		_ctx.field(entry, "id", SaveContext.Kind.TEXT, path)
		_ctx.field(entry, "giver", SaveContext.Kind.TEXT, path)
		_ctx.field(entry, "posted_day", SaveContext.Kind.WHOLE, path)
		_ctx.field(entry, "is_taken", SaveContext.Kind.BOOL, path)
	for key in ["done", "ended"]:
		var days: Variant = _ctx.field(quests, key, SaveContext.Kind.DICT, "quests")
		for id: Variant in [] if days == null else days:
			if not _ctx.is_kind(days[id], SaveContext.Kind.WHOLE):
				_ctx.report("quests %s" % key, "%s %s is not a day" % [id, days[id]])


## The shops: for each, how many of what it has left and has room for, and the day it was worked
## out.
func _check_shops(game: Dictionary) -> void:
	var shops: Variant = _ctx.field(game, "shops", SaveContext.Kind.DICT, "")
	if shops == null:
		return
	for shop: String in shops:
		var path := "shops %s" % shop
		if not shops[shop] is Dictionary:
			_ctx.report(path, "should be a dictionary")
			continue
		_ctx.field(shops[shop], "restocked_day", SaveContext.Kind.WHOLE, path)
		for key in ["stock", "room"]:
			var counts: Variant = _ctx.field(shops[shop], key, SaveContext.Kind.DICT, path)
			for item: Variant in [] if counts == null else counts:
				var count: Variant = counts[item]
				if not _ctx.is_kind(count, SaveContext.Kind.WHOLE) or count < 0:
					_ctx.report("%s %s" % [path, key], "%s %s is not a count" % [item, count])
