extends GutTest
## Pins what WorldGenerator makes for a few seeds, so that a refactor of it (moving the coast,
## dykes or vegetation into their own scripts) can be seen not to change a world: the same seed
## has to give the same terrain and objects, which saved games rely on. If a change is meant to
## alter the generated world, replace the fingerprints below.

## Chunks along the coast (its line is at x = -260, so chunks -9 to -7), around the river's mouth
## and inland, where the woods, wetland, creeks and dykes of the river are.
const CHUNKS: Array[Vector2i] = [
	Vector2i(-9, -3),
	Vector2i(-9, 0),
	Vector2i(-8, 1),
	Vector2i(-7, -1),
	Vector2i(-4, 0),
	Vector2i(-1, -1),
	Vector2i(0, 0),
	Vector2i(3, 2),
	Vector2i(6, -4),
	Vector2i(12, 1),
]
## Tiles asked one by one, for the answers that are not part of a chunk.
const PROBE_AREA := Rect2i(-290, -40, 90, 80)
const EXPECTED := {
	1: "29550aabedbc430feb16042b6920cf716df91689d319a51ff8d97e018ee86939",
	42: "20a4a8077ef18dee77aaef226bba5b8a6d6929375d9f0925dce2058a941e8905",
	2024: "9a9aff8a16999021bf7efb264d91eca1483d323a56549da6555ba98357e8bb96",
}


## A digest of the terrain and objects of the chunks, and of what a generator says of the tiles
## of PROBE_AREA that a chunk does not hold.
func _fingerprint(world_seed: int) -> String:
	var generator := WorldGenerator.new(world_seed)
	var text := ""
	for coords in CHUNKS:
		var chunk := generator.generate_chunk(coords)
		for y in Chunk.CHUNK_SIZE:
			for x in Chunk.CHUNK_SIZE:
				text += str(chunk.terrain_at(Vector2i(x, y)))
		for object in chunk.objects():
			text += "%s@%s;" % [object.type, object.pos]
	for y in range(PROBE_AREA.position.y, PROBE_AREA.end.y):
		text += str(generator.first_land_x(y))
		for x in range(PROBE_AREA.position.x, PROBE_AREA.end.x):
			var tile := Vector2i(x, y)
			text += "c" if generator.is_clay_spot(tile) else ""
			text += "f" if generator.is_ford(tile) else ""
			text += "w" if generator.is_forest(tile) else ""
	return text.sha256_text()


func test_generated_worlds_are_unchanged() -> void:
	var actual := {}
	for world_seed in [1, 42, 2024]:
		actual[world_seed] = _fingerprint(world_seed)
	assert_eq(actual, EXPECTED, "fingerprints: %s" % JSON.stringify(actual))
