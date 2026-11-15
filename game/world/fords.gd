class_name Fords
extends RefCounted
## The fords of a world (issue #96): where a creek runs shallow over a bed of stones (see
## CreekLayout `Bed.FORD`). A ford is floodplain terrain, walked like it, but drawn as a ford of its
## own (TerrainTileset `Layer.FORD`), and nobody leaves footprints in its water. Asked here and not
## of World, as the creeks are a pure function of the seed.

## How many seeds' creeks are kept (see `_creeks_of_seed`).
const KEPT_SEEDS := 4

## The creeks of the seeds asked about lately, by seed: a world keeps its seed, so this holds one
## or two (a test may make a few worlds).
static var _creeks_of_seed: Dictionary[int, CreekLayout] = {}


## Whether a tile of `world` is a ford: floodplain where the world's creek has its ford. A tile
## tilled or built over is no ford any more, nor is one whose chunk is not loaded.
static func is_ford(world: World, world_pos: Vector2i) -> bool:
	var chunk := world.chunk_at(Chunk.world_to_chunk(world_pos))
	if chunk == null or chunk.terrain_at(Chunk.local_pos(world_pos)) != Tile.Terrain.FLOODPLAIN:
		return false
	return _creeks(world.world_seed).bed_at(world_pos) == CreekLayout.Bed.FORD


static func _creeks(world_seed: int) -> CreekLayout:
	var creeks: CreekLayout = _creeks_of_seed.get(world_seed)
	if creeks == null:
		if _creeks_of_seed.size() >= KEPT_SEEDS:
			_creeks_of_seed.clear()
		creeks = CreekLayout.new(
			world_seed, RiverLine.new(world_seed), LandscapeRules.default_rules()
		)
		_creeks_of_seed[world_seed] = creeks
	return creeks
