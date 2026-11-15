class_name DebugFootprints
extends RefCounted
## For screenshots (`--footprints=<x>,<y>`): two trails of footprints from that tile, one eastwards
## with a gentle weave and one to the south that turns west, in snow with `--snow=1`, and else in
## the mud of worn ground that the rain has made soft. Walked after the views are up, so they draw.

const TRAIL_STEPS := 14
## How far the trail to the east weaves from side to side, in tiles.
const WEAVE := 1.5


static func create(world: World, start: Vector2i, is_snow: bool) -> void:
	var footprints := world.footprints
	var snow_checker := footprints.is_snowed_at
	footprints.is_snowed_at = func(_tile: Vector2i) -> bool: return is_snow
	var tiles: Array[Vector2i] = []
	for step in TRAIL_STEPS:
		tiles.append(start + Vector2i(step, roundi(sin(step * 0.6) * WEAVE)))
	for step in 1 + TRAIL_STEPS / 2:
		tiles.append(start + Vector2i(2, 4 + step))
	for step in TRAIL_STEPS / 2:
		tiles.append(start + Vector2i(1 - step, 4 + TRAIL_STEPS / 2))
	if not is_snow:
		for tile in tiles:
			world.set_wear_days(tile, PathRules.default_rules().path_after_days())
		world.set_muddy(true)
	for index in range(1, tiles.size()):
		footprints.step(world, tiles[index], Vector2(tiles[index] - tiles[index - 1]))
	footprints.is_snowed_at = snow_checker
