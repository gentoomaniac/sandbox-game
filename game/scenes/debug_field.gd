class_name DebugField
extends RefCounted
## For screenshots (`--field=<x>,<y>` in main.gd): a tilled field with one crop per growth
## stage in its top row and bare soil below. The chunks it covers must be loaded.


static func create(world: World, origin: Vector2i) -> void:
	var crop_type: Dictionary = WorldObjectTypes.TYPES[GameState.CROP]
	var stages: int = crop_type["growth_stages"]
	for x in stages:
		for y in 2:
			world.set_terrain(origin + Vector2i(x, y), Tile.Terrain.SOIL)
		var crop := WorldObject.new(GameState.CROP, origin + Vector2i(x, 0))
		crop.state["days_grown"] = x * int(crop_type["days_per_stage"])
		world.add_object(crop)
