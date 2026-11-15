class_name Footprints
extends RefCounted
## The footprints walkers leave on soft ground (#64): in snow, and in mud (the tidal mud, and the
## mud the rain makes of worn ground). They are a look only and are not saved: nothing else reads
## them, and a loaded game starts with clean ground. Numbers are in data/footprints.cfg.
##
## Only the loaded chunks keep prints (a walker on a chunk that is not loaded, as one on a far trip
## is, makes none: nobody sees them). Each chunk keeps a ring of the last `per_chunk` prints, so
## the cost has a bound however much is walked: a new print past the cap overwrites the oldest.
## One print is made for each tile a walker steps onto, the left and the right foot in turn, with
## its toes the way the walker goes.
##
## A print fades by its age, which is not time but the pace of the weather: each kind has its own
## clock (`age_of`) that runs faster in rain, in snowfall or in the thaw, so the prints of all
## walkers fade together and nothing is done to a print as it ages. `opacity_of` and the shader of
## FootprintView read that clock.

## A print was written to a slot of a chunk's ring (or killed there, see `check_chunk`).
signal printed(chunk_coords: Vector2i, slot: int)

enum Kind { NONE, SNOW, MUD }

## The art's cells: a left and a right foot of each kind, in the order SNOW, MUD (see
## tools/art/footprints.py).
const CELLS_PER_KIND := 2
## A print this far to the side of its tile's middle, in tiles, so the two feet walk apart.
const FOOT_SIDE_OFFSET := 0.2
## The born age of a print that is gone: it is older than any print can get.
const GONE := -1.0e9

## Tells whether snow lies on a tile; the view that draws the ground has the answer.
var is_snowed_at := func(_tile: Vector2i) -> bool: return false

var _rules: FootprintRules
var _rings: Dictionary[Vector2i, Ring] = {}
## The age of the prints of each kind (see `age_of`), in minutes of fair weather.
var _age := PackedFloat32Array([0.0, 0.0, 0.0])
var _last_minute := -1
## The chunks `check_next_chunk` has still to check in this round.
var _to_check: Array[Vector2i] = []


## The last prints of one chunk, as slots of parallel arrays: where the print lies (in tiles, the
## middle of its foot), how many quarter turns the picture is turned from toes up, its cell of the
## art and the age of its kind when it was made (`GONE` for a print that has vanished).
class Ring:
	extends RefCounted
	var position: PackedVector2Array
	var quarter_turns: PackedByteArray
	var cell: PackedByteArray
	var born: PackedFloat32Array
	## How many slots hold a print (or the remains of one).
	var size := 0
	## The slot the next print goes to.
	var next := 0

	func _init(capacity: int) -> void:
		position.resize(capacity)
		quarter_turns.resize(capacity)
		cell.resize(capacity)
		born.resize(capacity)


func _init(rules := FootprintRules.default_rules()) -> void:
	_rules = rules


## What a step onto `tile` leaves in the ground of `world`: snow where snow lies, mud on tidal
## mud that the tide does not cover and on worn ground the rain has made mud. Nothing on a way,
## a building or in the water.
func kind_at(world: World, tile: Vector2i) -> Kind:
	var chunk := world.chunk_at(Chunk.world_to_chunk(tile))
	if chunk == null or world.is_way_at(tile) or world.building_at(tile) != null:
		return Kind.NONE
	if is_snowed_at.call(tile):
		return Kind.SNOW
	if chunk.terrain_at(Chunk.local_pos(tile)) == Tile.Terrain.MUD:
		return Kind.NONE if world.is_flooded(tile) else Kind.MUD
	return Kind.MUD if world.is_muddy_at(tile) else Kind.NONE


## A walker steps onto `tile`, heading the way of `heading` (any length): leaves a print if the
## ground there is soft.
func step(world: World, tile: Vector2i, heading: Vector2) -> void:
	var kind := kind_at(world, tile)
	if kind == Kind.NONE or heading.is_zero_approx():
		return
	var quarter_turns := posmod(roundi(heading.angle() / (PI / 2.0)) + 1, 4)
	var toes := Vector2.UP.rotated(quarter_turns * PI / 2.0)
	# The feet follow each other along the axis the walker mostly goes on, so they alternate
	# without remembering whose step it was.
	var is_right := (tile.x if absf(heading.x) > absf(heading.y) else tile.y) % 2 != 0
	var side := toes.rotated(PI / 2.0) * (FOOT_SIDE_OFFSET if is_right else -FOOT_SIDE_OFFSET)
	var chunk_coords := Chunk.world_to_chunk(tile)
	var ring := _rings.get(chunk_coords) as Ring
	if ring == null:
		ring = Ring.new(_rules.per_chunk())
		_rings[chunk_coords] = ring
	var slot := ring.next
	ring.position[slot] = Vector2(tile) + Vector2(0.5, 0.5) + side
	ring.quarter_turns[slot] = quarter_turns
	ring.cell[slot] = (kind - 1) * CELLS_PER_KIND + (1 if is_right else 0)
	ring.born[slot] = _age[kind]
	ring.size = maxi(ring.size, slot + 1)
	ring.next = (slot + 1) % ring.born.size()
	printed.emit(chunk_coords, slot)


## Lets the prints age up to the game minute `total_minutes` (see GameClock.total_minutes) in the
## weather of now: `rain`, `snowfall` and `thaw` each 0 (none) to 1 (as strong as it gets). A jump
## of the clock (a night's sleep) ages them at the pace of the weather they wake to.
func advance_to(total_minutes: int, rain: float, snowfall: float, thaw: float) -> void:
	var minutes := 0 if _last_minute < 0 else maxi(total_minutes - _last_minute, 0)
	_last_minute = total_minutes
	_age[Kind.MUD] += minutes * (1.0 + _rules.mud_rain_gain() * rain)
	_age[Kind.SNOW] += (
		minutes * (1.0 + _rules.snow_snowfall_gain() * snowfall + _rules.snow_thaw_gain() * thaw)
	)


## How old the prints of a kind that were made now would be, in minutes of fair weather.
func age_of(kind: Kind) -> float:
	return _age[kind]


## How much of a print of this kind and `born` age is left to see: 1 for a new one, 0 for one
## that has faded.
func opacity_of(kind: Kind, born: float) -> float:
	var lasts := _rules.snow_lasts_minutes() if kind == Kind.SNOW else _rules.mud_lasts_minutes()
	return clampf(1.0 - (_age[kind] - born) / lasts, 0.0, 1.0)


## The ring of prints of a loaded chunk, or null if it holds none.
func ring_of(chunk_coords: Vector2i) -> Ring:
	return _rings.get(chunk_coords)


## The kind of a print in a slot of a ring.
func kind_of_slot(ring: Ring, slot: int) -> Kind:
	@warning_ignore("integer_division")
	return (ring.cell[slot] / CELLS_PER_KIND + 1) as Kind


## Forgets the prints of a chunk that was unloaded.
func forget_chunk(chunk_coords: Vector2i) -> void:
	_rings.erase(chunk_coords)


## Checks the prints of the next chunk that has any, one chunk each call: a print whose ground is
## not soft any more (the tide covers the mud, the rain stopped and it dried, the snow has melted
## or mud lies under new snow) is gone. A chunk at a time, so the walk over all of them costs a
## little in each of many frames, not much in one.
func check_next_chunk(world: World) -> void:
	if _to_check.is_empty():
		_to_check = _rings.keys()
	if _to_check.is_empty():
		return
	var chunk_coords: Vector2i = _to_check.pop_back()
	var ring := _rings.get(chunk_coords) as Ring
	if ring == null:
		return
	for slot in ring.size:
		if ring.born[slot] == GONE:
			continue
		if kind_at(world, Vector2i(ring.position[slot].floor())) != kind_of_slot(ring, slot):
			ring.born[slot] = GONE
			printed.emit(chunk_coords, slot)
