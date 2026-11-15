class_name VillageSite
extends RefCounted
## Where Wehlsbüll stands: a pure function of the seed (design/world/wehlsbuell.md, section 2). From
## the camp's row, north and south in steps of ROW_STEP rows, the first row whose coast and land fit
## the plan of the village (VillagePlan) and which the camp can walk to.

## How far apart the rows tried are.
const ROW_STEP := 4
## How far from the camp's row the search goes: the village needs the world's rows to itself.
const MAX_ROWS_FROM_CAMP := 900
## How many tiles the coast may wander in the village's rows, east and west of where it is in the
## middle row: the plan is laid out behind the dyke of the middle row, clear of what the coast does.
const COAST_TOLERANCE := 8
## Tiles the search for the camp's way looks at before it gives the row up.
const MAX_SEARCH_NODES := 400000

## The world tile of the plan's `u` 0, `v` 0: the first land tile of the middle row.
var origin: Vector2i


## The site of the village in the world of this seed, or null where there is none within
## MAX_ROWS_FROM_CAMP rows of the camp.
static func find(world_seed: int, plan := VillagePlan.default_plan()) -> VillageSite:
	var generator := WorldGenerator.new(world_seed)
	var river := RiverLine.new(world_seed)
	var camp := CampSite.spawn_of_seed(world_seed)
	var world := World.new(world_seed)
	var rows: Array[int] = [camp.y]
	for distance in range(ROW_STEP, MAX_ROWS_FROM_CAMP, ROW_STEP):
		rows.append_array([camp.y + distance, camp.y - distance])
	for row in rows:
		var site := VillageSite.new()
		site.origin = Vector2i(generator.first_land_x(row), row)
		if (
			site._has_straight_coast(generator, plan)
			and site._is_on_camps_side_of_the_river(river, camp)
			and site._has_dry_land_and_salt_marsh(generator, plan)
			and site._can_be_walked_to(world, generator, plan, camp)
		):
			return site
	return null


## The world tile of a tile of the plan.
func to_world(plan_tile: Vector2i) -> Vector2i:
	return origin + plan_tile


## The village's land in world tiles.
func land(plan: VillagePlan) -> Rect2i:
	return Rect2i(to_world(plan.area.position), plan.area.size)


## Rule 1: the coast is straight enough, so the dyke of every row of the village is within
## COAST_TOLERANCE tiles of the middle row's.
func _has_straight_coast(generator: WorldGenerator, plan: VillagePlan) -> bool:
	var land_rows := land(plan)
	for row in range(land_rows.position.y, land_rows.end.y):
		if absi(generator.first_land_x(row) - origin.x) > COAST_TOLERANCE:
			return false
	return true


## The camp can only walk to a village on its side of the river, which has no ford: asked before the
## search, as the search over the other side would look at every tile it could reach.
func _is_on_camps_side_of_the_river(river: RiverLine, camp: Vector2i) -> bool:
	var camp_is_north := camp.y < river.line_y(camp.x)
	return camp_is_north == (origin.y < river.line_y(origin.x))


## Rules 2 and 3: the ground inland of the dyke is dry and clear of water (the trees and stones are
## the builder's to fell), and the Warften seaward of it stand on salt marsh.
func _has_dry_land_and_salt_marsh(generator: WorldGenerator, plan: VillagePlan) -> bool:
	for warft in plan.warften:
		if warft["is_on_salt_marsh"]:
			for tile in plan.warft_tiles(warft):
				if generator.terrain_at(to_world(tile)) != Tile.Terrain.SALT_MARSH:
					return false
	var inland := Rect2i(
		to_world(Vector2i(plan.inland_from_u, plan.area.position.y)),
		Vector2i(plan.area.end.x - plan.inland_from_u, plan.area.size.y)
	)
	for y in range(inland.position.y, inland.end.y):
		for x in range(inland.position.x, inland.end.x):
			var terrain := generator.terrain_at(Vector2i(x, y))
			if terrain != Tile.Terrain.GRASS and terrain != Tile.Terrain.WETLAND:
				return false
	return true


## Rule 4: the way of the land from the camp to the east end of the main lane, over the generated
## land (the village's own land counts as cleared, as the builder will clear it). The one rule that
## needs a search, and so the last.
func _can_be_walked_to(
	world: World, generator: WorldGenerator, plan: VillagePlan, camp: Vector2i
) -> bool:
	var village_land := land(plan)
	var is_free := func(tile: Vector2i) -> bool:
		var chunk_coords := Chunk.world_to_chunk(tile)
		if not World.is_chunk_in_bounds(chunk_coords):
			return false
		if not world.is_chunk_loaded(chunk_coords):
			world.add_chunk(generator.generate_chunk(chunk_coords))
		if village_land.has_point(tile):
			return world.is_ground_walkable(tile)
		return world.is_walkable(tile)
	var goal := to_world(plan.main_lane_end())
	var search := PathSearch.new(
		camp, goal, is_free, func(_tile: Vector2i) -> float: return 1.0, MAX_SEARCH_NODES
	)
	while not search.is_over():
		search.step(MAX_SEARCH_NODES)
	return search.state == PathSearch.State.FOUND
