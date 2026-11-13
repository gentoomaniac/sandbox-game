class_name DebugField
extends RefCounted
## For screenshots (`--field=<x>,<y>`): a tilled field with a row of bare soil from
## dry to soaked, and below that the crops, CROPS_PER_ROW to a row, each with a crop in each
## growth stage and then a dead one, a tile of soil between them; the rows two tiles apart for
## the tall ones; a scarecrow stands between the soil row and the first crops. Whatever stood
## there is cleared. The chunks it covers must be loaded.

## So the whole field fits into the widest view.
const CROPS_PER_ROW := 3


static func create(world: World, origin: Vector2i) -> void:
	var crop_ids := CropRules.default_rules().crop_ids()
	var looks := CropRules.STAGES + 1
	var size := Vector2i(
		CROPS_PER_ROW * (looks + 1) - 1, 2 + ceili(crop_ids.size() / float(CROPS_PER_ROW)) * 2
	)
	for y in size.y:
		for x in size.x:
			_till(world, origin + Vector2i(x, y))
	for column in 5:
		world.set_moisture(origin + Vector2i(column, 0), column / 4.0)
	for index in crop_ids.size():
		var crop_type: Dictionary = WorldObjectTypes.TYPES[crop_ids[index]]
		@warning_ignore("integer_division")
		var start := Vector2i(index % CROPS_PER_ROW * (looks + 1), 2 + index / CROPS_PER_ROW * 2)
		for look in looks:
			var crop := WorldObject.new(crop_ids[index], origin + start + Vector2i(look, 0))
			if look < CropRules.STAGES:
				crop.state["growth"] = look * crop_type["growth_per_stage"]
			else:
				crop.state["crop_damage"] = 1.0
			world.add_object(crop)
	var scarecrow := WorldObject.new(WorldObjectTypes.SCARECROW, origin + Vector2i(4, 1))
	scarecrow.state["placed_day"] = world.clock.day
	world.remove_object(scarecrow.pos)
	world.add_object(scarecrow)


static func _till(world: World, pos: Vector2i) -> void:
	world.remove_object(pos)
	world.set_terrain(pos, Tile.Terrain.SOIL)
