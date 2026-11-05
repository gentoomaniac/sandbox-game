class_name InteriorLoader
extends RefCounted
## Turns a Tiled map (.tmx, with its external .tsx tileset) into an Interior. The .tmx stays
## the only source: it is read at runtime, with no export step. (The YATI importer is not
## used, because it needs engine classes that some Godot builds lack, and the state is
## wanted without a scene anyway.)
##
## Properties of the tiles of the tileset say what a cell means, on whichever layer it is:
## - `terrain`: a Tile.Terrain name, such as FLOOR or WALL;
## - `exit` (bool): the cell is the exit;
## - `object_type`: a WorldObjectTypes name; an object of it stands on the cell.
## Layers and cell positions follow the map; empty cells are left empty.
##
## Bad content fails loudly, but with asserts: they are debug-time checks for authored content.


## Reads the map in the file. Asserts if it is not one of ours (CSV layers, one external
## tileset).
static func load_interior(tmx_path: String) -> Interior:
	var interior := Interior.new()
	var tileset_path := ""
	var first_gid := 0
	var layer_csv := ""
	var is_in_data := false
	var layers: Array[PackedStringArray] = []
	var parser := _open(tmx_path)
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				match parser.get_node_name():
					"map":
						interior.size = Vector2i(
							parser.get_named_attribute_value("width").to_int(),
							parser.get_named_attribute_value("height").to_int()
						)
					"tileset":
						assert(tileset_path == "", "%s: more than one tileset" % tmx_path)
						first_gid = parser.get_named_attribute_value("firstgid").to_int()
						tileset_path = tmx_path.get_base_dir().path_join(
							parser.get_named_attribute_value("source")
						)
					"data":
						var encoding := parser.get_named_attribute_value("encoding")
						assert(
							encoding == "csv",
							"%s: layers must be CSV, not %s" % [tmx_path, encoding]
						)
						is_in_data = true
			XMLParser.NODE_TEXT:
				if is_in_data:
					layers.append(parser.get_node_data().split(",", false))
					is_in_data = false
	var tile_properties := _read_tile_properties(tileset_path)
	var has_exit := false
	for gids in layers:
		for index in gids.size():
			var gid := gids[index].strip_edges().to_int()
			if gid == 0:
				continue
			var pos := Vector2i(index % interior.size.x, index / interior.size.x)
			assert(tile_properties.has(gid - first_gid), "%s: no tile for gid %d" % [tmx_path, gid])
			var properties: Dictionary = tile_properties[gid - first_gid]
			has_exit = has_exit or properties.get("exit") == "true"
			_apply(interior, pos, properties)
	assert(has_exit, "%s: no tile with the exit property" % tmx_path)
	return interior


## The properties of each tile of a tileset file, by tile id.
static func _read_tile_properties(tsx_path: String) -> Dictionary:
	var properties := {}
	var tile_id := -1
	var parser := _open(tsx_path)
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		match parser.get_node_name():
			"tile":
				tile_id = parser.get_named_attribute_value("id").to_int()
				properties[tile_id] = {}
			"property":
				assert(tile_id >= 0, "%s: property outside a tile" % tsx_path)
				properties[tile_id][parser.get_named_attribute_value("name")] = (
					parser.get_named_attribute_value("value")
				)
	return properties


static func _apply(interior: Interior, pos: Vector2i, properties: Dictionary) -> void:
	if properties.has("terrain"):
		var terrain_name: String = properties["terrain"]
		assert(Tile.Terrain.has(terrain_name), "Unknown terrain: %s" % terrain_name)
		interior.set_terrain(pos, Tile.Terrain[terrain_name])
	if properties.get("exit") == "true":
		interior.exit_tile = pos
	if properties.has("object_type"):
		assert(
			WorldObjectTypes.TYPES.has(StringName(properties["object_type"])),
			"Unknown object type: %s" % properties["object_type"]
		)
		interior.add_object(WorldObject.new(StringName(properties["object_type"]), pos))


static func _open(path: String) -> XMLParser:
	var parser := XMLParser.new()
	var error := parser.open(path)
	assert(error == OK, "Can't read %s: %s" % [path, error_string(error)])
	return parser
