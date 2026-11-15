extends SceneTree
## Draws a top-down map of the generated land as a PNG, headless: one block of pixels per tile,
## the terrain as the ground colour and the objects (trees, dykes, ...) over it. It
## reads and writes no save. The colours are those of MapColors (see
## design/world/map-generation-review.md). At 4 px a tile or more, a dyke is drawn as a bank along
## its line over the ground, running on the diagonal where the game draws it so (see LineSlants).
##
##   godot --headless --path . -s tools/world_map.gd -- --seed=42 --center=0,0 --size=320 \
##       --scale=3 --out=/abs/path/map.png
##
## With --village the seed's village Wehlsbüll is built into the land first (see VillageBuilder),
## and the map shows it: unless given, the centre is the village's middle and the size is 128
## tiles at scale 8.

## From this many pixels a tile up, a dyke is drawn along its line (see `_draw_dyke`).
const DYKE_LINE_SCALE := 4
## How far out from its line a dyke reaches on the map, in tiles.
const DYKE_HALF_WIDTH := 0.36

## The world the chunks are put into: the village's edits are replayed on them from it.
var _world: World


func _init() -> void:
	var options := _options()
	var world_seed := int(options.get("seed", "1"))
	var generator := WorldGenerator.new(world_seed)
	_world = World.new(world_seed)
	var has_village := options.has("village")
	var village_center := Vector2i.ZERO
	if has_village:
		var plan := VillagePlan.default_plan()
		var site := VillageSite.find(world_seed)
		var reason := VillageBuilder.build(_world, site, plan)
		if reason != "":
			push_error("No village: %s" % reason)
		village_center = site.to_world(plan.area.get_center())
	var size := int(options.get("size", "128" if has_village else "320"))
	var tile_px := int(options.get("scale", "8" if has_village else "3"))
	var center := _vector(options["center"]) if options.has("center") else village_center
	var top_left := center - Vector2i.ONE * (size / 2)
	var image := Image.create_empty(size * tile_px, size * tile_px, false, Image.FORMAT_RGB8)
	var dykes: Dictionary[Vector2i, bool] = {}
	var first_chunk := Chunk.world_to_chunk(top_left)
	var last_chunk := Chunk.world_to_chunk(top_left + Vector2i.ONE * size)
	for chunk_y in range(first_chunk.y, last_chunk.y + 1):
		for chunk_x in range(first_chunk.x, last_chunk.x + 1):
			var chunk := generator.generate_chunk(Vector2i(chunk_x, chunk_y))
			if chunk == null:
				continue
			# The village's edits are replayed on the chunk by the world.
			_world.add_chunk(chunk)
			for local_y in Chunk.CHUNK_SIZE:
				for local_x in Chunk.CHUNK_SIZE:
					var local := Vector2i(local_x, local_y)
					var shown := Chunk.to_world(chunk.coords, local) - top_left
					if shown.x < 0 or shown.y < 0 or shown.x >= size or shown.y >= size:
						continue
					var color := MapColors.of_tile(_world, chunk, local)
					var object := chunk.object_at(local)
					if (
						tile_px >= DYKE_LINE_SCALE
						and object != null
						and object.type == WorldObjectTypes.DYKE
						and color == MapColors.OBJECT_COLORS[&"dyke"]
					):
						dykes[shown] = true
						color = MapColors.ground_of(_world.world_seed, chunk, local)
					image.fill_rect(Rect2i(shown * tile_px, Vector2i.ONE * tile_px), color)
	for tile: Vector2i in dykes:
		_draw_dyke(image, tile, tile_px, dykes)
	image.save_png(options["out"])
	quit()


## Draws a dyke on `tile` (of the map) as a bank DYKE_HALF_WIDTH of a tile either side of its
## line: arms from the middle to the sides it joins, or on a slanted corner a straight line from the
## middle of one side to the other.
func _draw_dyke(image: Image, tile: Vector2i, tile_px: int, dykes: Dictionary) -> void:
	var mask := _dyke_mask(tile, dykes)
	# The map has no World of the chunks' lines, so it works the masks out of the dykes it drew.
	var is_slanted := LineSlants.slanted_sides_at(tile, _dyke_mask.bind(dykes)) != 0
	var middle := Vector2(0.5, 0.5)
	var ends := PackedVector2Array()
	for side in World.CONNECTION_SIDES.size():
		if mask & (1 << side):
			ends.append(middle + Vector2(World.CONNECTION_SIDES[side]) / 2.0)
	var segments: Array[PackedVector2Array] = []
	if is_slanted:
		segments.append(ends)
	else:
		for end in ends:
			segments.append(PackedVector2Array([middle, end]))
		if ends.is_empty():
			segments.append(PackedVector2Array([middle, middle]))
	for y in tile_px:
		for x in tile_px:
			var point := (Vector2(x, y) + middle) / tile_px
			for segment in segments:
				var nearest := Geometry2D.get_closest_point_to_segment(
					point, segment[0], segment[1]
				)
				if point.distance_to(nearest) <= DYKE_HALF_WIDTH:
					image.set_pixelv(
						tile * tile_px + Vector2i(x, y), MapColors.OBJECT_COLORS[&"dyke"]
					)
					break


func _dyke_mask(tile: Vector2i, dykes: Dictionary) -> int:
	var mask := 0
	for side in World.CONNECTION_SIDES.size():
		if dykes.has(tile + World.CONNECTION_SIDES[side]):
			mask |= 1 << side
	return mask


func _options() -> Dictionary:
	var options := {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else ""
	return options


func _vector(text: String) -> Vector2i:
	var parts := text.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
