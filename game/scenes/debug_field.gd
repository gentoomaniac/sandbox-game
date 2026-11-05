class_name DebugField
extends RefCounted
## For screenshots (`--field=<x>,<y>` in main.gd): a tilled field with a row of bare soil from
## dry to soaked, and below that one row per crop, two tiles apart for the tall ones, with a crop
## in each growth stage and then a dead one. Whatever stood there is cleared. The chunks it
## covers must be loaded.


static func create(world: World, origin: Vector2i) -> void:
	for column in 5:
		var pos := _till(world, origin + Vector2i(column, 0))
		world.set_moisture(pos, column / 4.0)
	var row := 2
	for crop_id in CropRules.default_rules().crop_ids():
		var crop_type: Dictionary = WorldObjectTypes.TYPES[crop_id]
		for look in CropRules.STAGES + 1:
			var pos := _till(world, origin + Vector2i(look, row))
			var crop := WorldObject.new(crop_id, pos)
			if look < CropRules.STAGES:
				crop.state["growth"] = look * crop_type["growth_per_stage"]
			else:
				crop.state["crop_damage"] = 1.0
			world.add_object(crop)
		row += 2


static func _till(world: World, pos: Vector2i) -> Vector2i:
	world.remove_object(pos)
	world.set_terrain(pos, Tile.Terrain.SOIL)
	return pos
