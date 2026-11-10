class_name ReachableTiles
extends RefCounted
## The tiles a walker can get to from where it stands without crossing what stops it: fences,
## walls, water, cliffs. How a skip of time finds where an animal or a villager could have
## wandered to, with the same collision rules as their steps.


## The tiles within `radius` tiles of `start` (the tile itself too) that can be walked to over
## tiles for which `is_free` (a Callable taking a tile) says so, in the order they are found.
static func within(start: Vector2i, radius: float, is_free: Callable) -> Array[Vector2i]:
	var found: Array[Vector2i] = [start]
	var seen := {start: true}
	var next := 0
	while next < found.size():
		var tile := found[next]
		next += 1
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var neighbour := tile + step
			if (
				seen.has(neighbour)
				or Vector2(neighbour - start).length() > radius
				or not is_free.call(neighbour)
			):
				continue
			seen[neighbour] = true
			found.append(neighbour)
	return found
