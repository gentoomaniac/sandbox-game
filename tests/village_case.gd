class_name VillageCase
extends GutTest
## What the tests of the built village share: a world of each seed with the village built once for
## all the tests, and ways to look at it by the plan's own tiles (`u`, `v`).

const SEEDS := [1, 4]
const SAVE_DIR := "user://test_village_builder"
const SAVE_PATH := SAVE_DIR + "/world.json"

var _plan := VillagePlan.default_plan()
## {seed: [world, site, generator]}, each built once for all the tests.
var _built := {}


func before_all() -> void:
	for world_seed: int in SEEDS:
		var world := World.new(world_seed)
		var site := VillageSite.find(world_seed)
		assert_eq(VillageBuilder.build(world, site, _plan), "")
		_built[world_seed] = [world, site, WorldGenerator.new(world_seed)]


func after_each() -> void:
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR.path_join(file_name))


func _world(world_seed: int) -> World:
	return _built[world_seed][0]


func _site(world_seed: int) -> VillageSite:
	return _built[world_seed][1]


func _generator(world_seed: int) -> WorldGenerator:
	return _built[world_seed][2]


## Loads the chunk of a tile into a world, which replays the edits on it.
func _load(world: World, generator: WorldGenerator, tile: Vector2i) -> void:
	var coords := Chunk.world_to_chunk(tile)
	if not world.is_chunk_loaded(coords):
		world.add_chunk(generator.generate_chunk(coords))


func _terrain_at(world_seed: int, plan_tile: Vector2i) -> Tile.Terrain:
	var tile := _site(world_seed).to_world(plan_tile)
	_load(_world(world_seed), _generator(world_seed), tile)
	return _world(world_seed).tile_at(tile).terrain


func _object_at(world_seed: int, plan_tile: Vector2i) -> WorldObject:
	var tile := _site(world_seed).to_world(plan_tile)
	_load(_world(world_seed), _generator(world_seed), tile)
	return _world(world_seed).object_at(tile)


func _land_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for v in range(_plan.area.position.y, _plan.area.end.y):
		for u in range(_plan.area.position.x, _plan.area.end.x):
			tiles.append(Vector2i(u, v))
	return tiles


func _edits_of(world: World) -> Dictionary:
	var edits := World.dict_of(world.snapshot())
	return {"terrain": edits["terrain_edits"], "objects": edits["object_edits"]}


func _is_planned_object(type: StringName) -> bool:
	return _plan.objects.any(func(group: Dictionary) -> bool: return group["type"] == type)
