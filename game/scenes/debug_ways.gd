class_name DebugWays
extends RefCounted
## For screenshots (`--ways=<x>,<y>`): a sample of the ways laid on grass from that tile: the plank
## walk on the left and the stone path beside it on the right, each with a straight run both ways,
## an L, a T, a crossing, a road two tiles wide both ways and a tile alone. Loads the chunks it
## covers itself.

## One kind of way: `#` is a piece, `.` is free.
const SAMPLE: PackedStringArray = [
	"#.#####.#...",
	"#.......#...",
	"#.......#...",
	"#.......####",
	"#...........",
	"............",
	"#####...#...",
	"..#.....#...",
	"..#...#####.",
	"..#.....#...",
	"##......#...",
	"##...#......",
	"##....#####.",
	"##....#####.",
]
## The free tiles between the planks and the stones, and round the sample.
const MARGIN := 2
const KINDS: Array[StringName] = [WorldObjectTypes.PLANK_WALK, WorldObjectTypes.STONE_PATH]


static func create(world: World, start: Vector2i) -> void:
	var width := SAMPLE[0].length()
	var generator := WorldGenerator.new(world.world_seed)
	for kind in KINDS.size():
		var origin := start + Vector2i(kind * (width + MARGIN), 0)
		for y in SAMPLE.size():
			for x in width:
				var tile := origin + Vector2i(x, y)
				var coords := Chunk.world_to_chunk(tile)
				if not world.is_chunk_loaded(coords):
					world.add_chunk(generator.generate_chunk(coords))
				world.remove_object(tile)
				world.set_terrain(tile, Tile.Terrain.GRASS)
				if SAMPLE[y][x] == "#":
					world.add_object(WorldObject.new(KINDS[kind], tile))
