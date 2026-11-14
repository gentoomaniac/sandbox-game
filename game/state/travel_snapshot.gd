class_name TravelSnapshot
extends RefCounted
## What a search on a worker thread needs of the world that the travel masks do not have, copied
## on the main thread so that the worker reads nothing that changes: the tiles of the buildings (all
## closed to villagers, the doors too) and the wear of the grass, for the cost of the lanes. Made
## again when the world has changed (`change_count`: a building put up, an edit) or when it is old
## (the wear grows with every step, and a search does not mind it a few seconds late).
##
## How it all works: design/tech/pathfinding.md.

## The tile of each building tile, to the building.
var buildings: Dictionary
## The steps of wear of each worn tile (see `World.wear_tile`).
var wear: Dictionary
var change_count: int
var made_at_usec: int


static func of(world: World, now_usec: int) -> TravelSnapshot:
	var snapshot := TravelSnapshot.new()
	snapshot.buildings = world.building_tiles()
	snapshot.wear = world.wear_steps()
	snapshot.change_count = world.change_count
	snapshot.made_at_usec = now_usec
	return snapshot


## Whether it still says what the world says, within `most_usec` for the wear.
func is_current(world: World, now_usec: int, most_usec: int) -> bool:
	return change_count == world.change_count and now_usec - made_at_usec <= most_usec
