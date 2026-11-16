class_name SaveEconomyChecks
extends RefCounted
## The checks of the village's trade and the quests: what the shops have, and the quests posted,
## taken, done and ended.

var _ctx: SaveContext


func _init(context: SaveContext) -> void:
	_ctx = context


## The shops: for each, how many of what it has left and has room for, and the day it was worked
## out.
func check_shops(game: Dictionary) -> void:
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


## The quests: those posted or taken, each with its id, giver, the day it was posted and whether it
## is taken, and the day each quest that was done and each that ended was last seen.
func check_quests(game: Dictionary) -> void:
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
