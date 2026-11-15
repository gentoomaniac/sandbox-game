extends SceneTree
## Draws a top-down map of the generated land as a PNG, headless: one block of pixels per tile,
## the terrain as the ground colour and the objects (trees, dykes, ...) over it. It
## reads and writes no save. See design/world/map-generation-review.md for the colours.
##
##   godot --headless --path . -s tools/world_map.gd -- --seed=42 --center=0,0 --size=320 \
##       --scale=3 --out=/abs/path/map.png

const OBJECT_COLORS := {
	&"oak": Color("12401a"),
	&"beech": Color("12401a"),
	&"birch": Color("1b5e20"),
	&"alder": Color("1b5e20"),
	&"willow": Color("6b8e23"),
	&"pine": Color("06290a"),
	&"spruce": Color("06290a"),
	&"dead_tree": Color("5d4037"),
	&"berry_bush": Color("7cb342"),
	&"shrub": Color("7cb342"),
	&"fern_bush": Color("7cb342"),
	&"sapling": Color("7cb342"),
	&"dyke": Color("8d6e63"),
	&"reeds": Color("c0ca33"),
	&"stone": Color("9e9e9e"),
	&"boulder": Color("757575"),
	&"ewer": Color("000000"),
}
const TERRAIN_COLORS := {
	Tile.Terrain.GRASS: Color("c8e6c9"),
	Tile.Terrain.WATER: Color("1e88e5"),
	Tile.Terrain.WETLAND: Color("80cbc4"),
	Tile.Terrain.FLOODPLAIN: Color("dce775"),
	Tile.Terrain.MUD: Color("bcaaa4"),
	Tile.Terrain.SALT_MARSH: Color("c5e1a5"),
	Tile.Terrain.SEA: Color("0d47a1"),
	Tile.Terrain.WARFT: Color("a1887f"),
}


func _init() -> void:
	var options := _options()
	var size := int(options.get("size", "320"))
	var tile_px := int(options.get("scale", "3"))
	var center := _vector(options.get("center", "0,0"))
	var generator := WorldGenerator.new(int(options.get("seed", "1")))
	var top_left := center - Vector2i.ONE * (size / 2)
	var image := Image.create_empty(size * tile_px, size * tile_px, false, Image.FORMAT_RGB8)
	var first_chunk := Chunk.world_to_chunk(top_left)
	var last_chunk := Chunk.world_to_chunk(top_left + Vector2i.ONE * size)
	for chunk_y in range(first_chunk.y, last_chunk.y + 1):
		for chunk_x in range(first_chunk.x, last_chunk.x + 1):
			var chunk := generator.generate_chunk(Vector2i(chunk_x, chunk_y))
			if chunk == null:
				continue
			for local_y in Chunk.CHUNK_SIZE:
				for local_x in Chunk.CHUNK_SIZE:
					var local := Vector2i(local_x, local_y)
					var shown := Chunk.to_world(chunk.coords, local) - top_left
					if shown.x < 0 or shown.y < 0 or shown.x >= size or shown.y >= size:
						continue
					image.fill_rect(
						Rect2i(shown * tile_px, Vector2i.ONE * tile_px), _color_of(chunk, local)
					)
	image.save_png(options["out"])
	quit()


func _color_of(chunk: Chunk, local: Vector2i) -> Color:
	var object := chunk.object_at(local)
	if object != null and OBJECT_COLORS.has(object.type):
		return OBJECT_COLORS[object.type]
	return TERRAIN_COLORS.get(chunk.terrain_at(local), Color.MAGENTA)


func _options() -> Dictionary:
	var options := {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1]
	return options


func _vector(text: String) -> Vector2i:
	var parts := text.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
