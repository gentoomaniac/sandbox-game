class_name TravelMask
extends RefCounted
## What a villager's feet need to know of the tiles of one chunk that is not loaded (see
## design/villagers/travel.md): one byte of flags a tile, in the order of the chunk's tiles. It
## answers what `Npcs.can_stand_at` answers on the loaded chunk, but for the buildings, which the
## world is asked live, and the tide and the season, which are given to each question.
##
## How it all works: design/tech/pathfinding.md.

const BLOCKED := 1 << 0
## Tidal mud: blocked while the water covers it (`Tide.floods`).
const MUD := 1 << 1
## A deck is walked on whatever the ground and the tide.
const DECK := 1 << 2
## Something that does not block the way but is spoiled by feet (see `NpcTravel.is_trampled`).
const OBJECT := 1 << 3
## A plant of the season: what it does to walking counts only while it is present, so it is kept
## in `_seasonal_objects` and the flags are those of the ground alone.
const SEASONAL := 1 << 4
## Grass or floodplain: it wears to a lane where it is walked (`Tile.wears`).
const WEARS := 1 << 5

var coords: Vector2i
var _flags := PackedByteArray()
var _seasonal_objects: Dictionary[int, WorldObject] = {}
var _vegetation: Vegetation
var _world_seed: int


## The mask of `chunk`, with the chunks W, N and NW of it that exist (a big object reaches east
## and south of its own tile, at most `WorldObjectTypes.MAX_FOOTPRINT`). All with the edits on.
func _init(chunk: Chunk, neighbours: Array[Chunk], plants: Vegetation, seed_value: int) -> void:
	coords = chunk.coords
	_vegetation = plants
	_world_seed = seed_value
	_flags.resize(Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE)
	var ground_flags: Array[int] = []
	for terrain in Tile.Terrain.values():
		ground_flags.append(_ground_flags(terrain))
	for y in Chunk.CHUNK_SIZE:
		for x in Chunk.CHUNK_SIZE:
			var local := Vector2i(x, y)
			_flags[_index(local)] = ground_flags[chunk.terrain_at(local)]
	for object in chunk.objects():
		_stamp_object(object)
	for neighbour in neighbours:
		for object in neighbour.objects():
			_stamp_object(object)


## Whether a villager can stand on the tile at `local` (a position in the chunk) at the day and
## with the tide level given. Buildings are not known here.
func is_free(local: Vector2i, tide_level: float, day: int) -> bool:
	var flags := _flags_at(local, day)
	if flags & DECK:
		return true
	if flags & BLOCKED:
		return false
	return not (flags & MUD and Tide.floods(Chunk.to_world(coords, local), tide_level))


## Whether the tile has an object that feet spoil, at the day given.
func is_trampled(local: Vector2i, day: int) -> bool:
	return _flags_at(local, day) & OBJECT != 0


## Whether the grass of the tile wears to a lane.
func wears(local: Vector2i) -> bool:
	return _flags[_index(local)] & WEARS != 0


static func _ground_flags(terrain: Tile.Terrain) -> int:
	var tile := Tile.new()
	tile.terrain = terrain
	var flags := 0
	if not tile.is_walkable():
		flags |= BLOCKED
	if terrain == Tile.Terrain.MUD:
		flags |= MUD
	if tile.wears():
		flags |= WEARS
	return flags


static func _object_flags(object: WorldObject) -> int:
	var type := object.type_data()
	var flags := 0
	if type.get("deck", false):
		flags |= DECK
	if object.blocks_walking():
		flags |= BLOCKED
	if NpcTravel.is_trampled(object):
		flags |= OBJECT
	return flags


## Puts the object on the tiles of the chunk that it covers.
func _stamp_object(object: WorldObject) -> void:
	for pos in object.tiles():
		if Chunk.world_to_chunk(pos) != coords:
			continue
		var index := _index(Chunk.local_pos(pos))
		if object.type_data().get("seasonal") == WorldObjectTypes.DORMANCY:
			_flags[index] |= SEASONAL
			_seasonal_objects[index] = object
		else:
			_flags[index] |= _object_flags(object)


## The flags of a tile as they are on a day: with its seasonal plant, if that is present.
func _flags_at(local: Vector2i, day: int) -> int:
	var index := _index(local)
	var flags := _flags[index]
	if flags & SEASONAL:
		var plant := _seasonal_objects[index]
		if _vegetation.is_present(plant.type, _world_seed, plant.pos, day):
			flags |= _object_flags(plant)
	return flags


func _index(local: Vector2i) -> int:
	return local.y * Chunk.CHUNK_SIZE + local.x
