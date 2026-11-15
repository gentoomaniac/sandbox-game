class_name DebugFootprints
extends RefCounted
## For screenshots (`--footprints=<x>,<y>`): two trails of footprints from that tile, one straight
## to the east and one diagonally to the north east, in snow with `--snow=1`, and else in the mud
## of worn ground that the rain has made soft. Walked after the views are up, so they draw.

## How long each trail is, in tiles.
const TRAIL_LENGTH := 8.0
## How far to the north of the first trail the diagonal one starts, in tiles.
const DIAGONAL_NORTH := 1
## A trail is walked in pieces this long, as a frame of walking is.
const PIECE := 0.1
const DIRECTIONS: Array[Vector2] = [Vector2.RIGHT, Vector2(1.0, -1.0)]


static func create(world: World, start: Vector2i, is_snow: bool) -> void:
	var footprints := world.footprints
	var snow_checker := footprints.is_snowed_at
	footprints.is_snowed_at = func(_tile: Vector2i) -> bool: return is_snow
	var pieces := int(TRAIL_LENGTH / PIECE)
	for trail in DIRECTIONS.size():
		var toes := DIRECTIONS[trail].normalized()
		var from := Vector2(start + Vector2i(0, -trail * DIAGONAL_NORTH)) + Vector2(0.5, 0.5)
		if not is_snow:
			for piece in pieces:
				var tile := Vector2i((from + toes * piece * PIECE).floor())
				# The feet lie to either side of the line, so the tiles next to it wear too.
				for around in [
					Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT
				]:
					world.set_wear_days(tile + around, PathRules.default_rules().path_after_days())
			world.set_muddy(true)
		var stride := Footprints.Stride.new()
		for piece in pieces:
			var at := from + toes * piece * PIECE
			footprints.walk(world, stride, at, at + toes * PIECE)
	footprints.is_snowed_at = snow_checker
