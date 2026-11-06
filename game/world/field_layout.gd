class_name FieldLayout
extends RefCounted
## The fields the land is cut into (see data/landscape.cfg): rows of fields between straight
## boundaries running east-west, each row cut into fields by boundaries running north-south. A
## pure function of the seed and the position, like the rest of the generator.
##
## A stretch of boundary is an east-west boundary between two north-south ones of the row below
## it, or a north-south boundary between two east-west ones. Each stretch is there or not, has
## one kind (Knick, wall or fence) and one gap, never at its ends, so no field is shut in: a
## row is open from end to end through the gaps of its north-south stretches, and each
## east-west boundary has a gap in every one of its stretches. What the generator makes of a
## boundary depends on the land (see WorldGenerator).

## What `boundary_at` gives for the gap of a stretch.
const GAP := &"gap"

const _LINE_SALT := 21
const _COLUMN_SALT := 22
const _PIECE_SALT := 23
const _GAP_SALT := 24
const _KIND_SALT := 25

var _seed: int
var _row_height: int
var _row_jitter: int
var _field_width: int
var _field_jitter: int
var _boundary_chance: float
## [cumulative share, kind] in the order of the data file, the shares summing to 1.
var _kinds: Array[Array] = []
## The area worked out at once (see `cover`), and what each of its tiles is, row by row.
var _covered := Rect2i()
var _covered_boundaries: Array[StringName] = []


func _init(world_seed: int, rules := LandscapeRules.default_rules()) -> void:
	_seed = world_seed
	_row_height = int(rules.value("fields", "row_height"))
	_row_jitter = int(rules.value("fields", "row_jitter"))
	_field_width = int(rules.value("fields", "field_width"))
	_field_jitter = int(rules.value("fields", "field_jitter"))
	_boundary_chance = rules.value("fields", "boundary_chance")
	var shares := rules.kind_shares()
	var total := 0.0
	for share: float in shares.values():
		total += share
	var sum := 0.0
	for kind: StringName in shares:
		sum += shares[kind] / total
		_kinds.append([sum, kind])


## Works out the boundaries of an area at once, for whoever asks about its tiles many times (the
## generator asks about every tile of a chunk and its sides): `boundary_at` then looks them up
## until the next call.
func cover(area: Rect2i) -> void:
	_covered = Rect2i()
	_covered_boundaries.clear()
	for y in range(area.position.y, area.end.y):
		var row := _row_of(y)
		# Off the row's east-west boundary, only the columns of its north-south ones need asking.
		var columns_x: Array[int] = []
		if y != _line_y(row):
			var column := _column_of(area.position.x, row)
			while _column_x(column, row) < area.end.x:
				columns_x.append(_column_x(column, row))
				column += 1
		for x in range(area.position.x, area.end.x):
			var is_off := y != _line_y(row) and not columns_x.has(x)
			_covered_boundaries.append(&"" if is_off else boundary_at(Vector2i(x, y)))
	_covered = area


## What a tile is on a field boundary: the kind of its stretch (an object type), GAP, or &"" if
## it is on none.
func boundary_at(pos: Vector2i) -> StringName:
	if _covered.has_point(pos):
		var local := pos - _covered.position
		return _covered_boundaries[local.y * _covered.size.x + local.x]
	var row := _row_of(pos.y)
	var line_y := _line_y(row)
	var column := _column_of(pos.x, row)
	var column_x := _column_x(column, row)
	if pos.y == line_y:
		var key := Vector2i(2 * column, row)
		var end := _column_x(column + 1, row)
		var gap := _gap_of(key, column_x, end)
		# Not right below the end of a north-south stretch of the row above, which would close it.
		if _column_x(_column_of(gap, row - 1), row - 1) == gap:
			gap += 1 if gap < end - 2 else -1
		return _stretch(key, pos.x, gap)
	if pos.x == column_x:
		var key := Vector2i(2 * column + 1, row)
		return _stretch(key, pos.y, _gap_of(key, line_y, _line_y(row + 1)))
	return &""


## Where the gap of the stretch `key` is, that runs from `start` (where the boundary it starts
## from is) to `end`: two tiles or more from both, so the tiles beside it are on no boundary.
func _gap_of(key: Vector2i, start: int, end: int) -> int:
	return start + 2 + PositionHash.of(key, _seed + _GAP_SALT) % (end - start - 3)


## What the tile `at` of the stretch `key` is.
func _stretch(key: Vector2i, at: int, gap: int) -> StringName:
	if _roll(key, _PIECE_SALT) >= _boundary_chance:
		return &""
	if at == gap:
		return GAP
	var roll := _roll(key, _KIND_SALT)
	for entry: Array in _kinds:
		if roll < entry[0]:
			return entry[1]
	return _kinds[-1][1]


## The row of fields a tile row is in: the one whose northern boundary is at or above it.
func _row_of(y: int) -> int:
	var row := floori(float(y) / _row_height)
	return row - 1 if y < _line_y(row) else row


func _line_y(row: int) -> int:
	return (
		row * _row_height
		+ PositionHash.of(Vector2i(row, 0), _seed + _LINE_SALT) % (_row_jitter + 1)
	)


## The field of a row a tile column is in: the one whose western boundary is at or left of it.
func _column_of(x: int, row: int) -> int:
	var column := floori(float(x) / _field_width)
	return column - 1 if x < _column_x(column, row) else column


func _column_x(column: int, row: int) -> int:
	return (
		column * _field_width
		+ PositionHash.of(Vector2i(column, row), _seed + _COLUMN_SALT) % (_field_jitter + 1)
	)


func _roll(key: Vector2i, salt: int) -> float:
	return PositionHash.of(key, _seed + salt) % 10000 / 10000.0
