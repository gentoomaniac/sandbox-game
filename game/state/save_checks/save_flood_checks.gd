class_name SaveFloodChecks
extends RefCounted
## The checks of the sea's surge and the flood on the land, in the save of the world: the levels
## and phase, and the tiles the water left wet, salty or muddy and the repairs made to them.

## The highest the sea or the water on the land may stand in a save, in centimetres.
const MAX_LEVEL_CM := 1000

var _ctx: SaveContext


func _init(context: SaveContext) -> void:
	_ctx = context


## The surge and the water it left in `world`: whole numbers in range, and a known phase.
func check(world: Dictionary) -> void:
	var surge: Variant = _ctx.field(world, "surge", SaveContext.Kind.DICT, "world")
	if surge != null:
		for key in ["level_cm", "peak_minute", "hold_minutes", "last_rolled_tide"]:
			_ctx.field(surge, key, SaveContext.Kind.WHOLE, "world surge")
		_ctx.check_between(surge.get("level_cm"), 0, MAX_LEVEL_CM, "world surge", "level_cm")
	var flood: Variant = _ctx.field(world, "flood", SaveContext.Kind.DICT, "world")
	if flood != null:
		for key in ["level_cm", "drain_minute"]:
			_ctx.field(flood, key, SaveContext.Kind.WHOLE, "world flood")
		_ctx.check_between(flood.get("level_cm"), 0, MAX_LEVEL_CM, "world flood", "level_cm")
		var phase: Variant = _ctx.field(flood, "phase", SaveContext.Kind.TEXT, "world flood")
		if phase != null and not str(phase).to_upper() in FloodState.Phase:
			_ctx.report("world flood", "unknown phase %s" % phase)
	for key in ["flood_wet", "flood_salt", "flood_mud", "flood_repairs"]:
		_ctx.check_entries(world, key, SaveContext.Kind.WHOLE)
	var met: Variant = _ctx.field(world, "flood_met_chunks", SaveContext.Kind.LIST, "world")
	if met != null and not met.all(_ctx.is_vector):
		_ctx.report("world flood_met_chunks", "should be a list of [x, y]")
	var wet: Variant = world.get("flood_wet")
	if wet is Array:
		for index in wet.size():
			if (
				wet[index] is Array
				and wet[index].size() == 3
				and _ctx.is_kind(wet[index][2], SaveContext.Kind.WHOLE)
			):
				_ctx.check_between(
					wet[index][2], 1, MAX_LEVEL_CM, "world flood_wet %d" % index, "depth"
				)
