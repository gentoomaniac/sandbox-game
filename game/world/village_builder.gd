class_name VillageBuilder
extends RefCounted
## Writes Wehlsbüll into a world once, when a new game starts (design/world/wehlsbuell.md): terrain
## and object edits, saved like anything else the player does. It reads only the plan, the site and
## the generator's public functions, and makes no random choice, so the same seed always gives the
## same village.

## What the builder leaves where it clears the ground: the sea dyke runs on through the land.
const KEPT_WHEN_CLEARING: Array[StringName] = [WorldObjectTypes.DYKE]
## A big object is stored at its own tile only, so what covers the land may start this far up and
## left of it.
const BIG_OBJECT_REACH := WorldObjectTypes.MAX_FOOTPRINT - Vector2i.ONE


## Builds the village: the land (see `build_land`), the buildings, and the record of it in
## `world.village`. Returns why it did not, or "" when it did.
static func build(world: World, site: VillageSite, plan: VillagePlan) -> String:
	return _build(world, site, plan, true)


## Clears the ground, lays the Warften, ponds, the Sielzug, the fields' boundaries, the walls and
## fences and the things that stand on the ground, but puts up no building. Returns why it did not,
## or "" when it did: the land of the village has to be as the generator made it, with nothing of
## the player's on it.
static func build_land(world: World, site: VillageSite, plan: VillagePlan) -> String:
	return _build(world, site, plan, false)


static func _build(
	world: World, site: VillageSite, plan: VillagePlan, with_buildings: bool
) -> String:
	var land := site.land(plan)
	var refusal := _refusal(world, land)
	if refusal != "":
		return refusal
	var generator := WorldGenerator.new(world.world_seed)
	var loaded := load_chunks(
		world, generator, land.grow_individual(BIG_OBJECT_REACH.x, BIG_OBJECT_REACH.y, 0, 0)
	)
	_clear_inland(world, site, plan)
	for warft in plan.warften:
		for tile in plan.warft_tiles(warft):
			world.set_terrain(site.to_world(tile), Tile.Terrain.WARFT)
	for tile in plan.pond_tiles():
		_lay_water(world, site.to_world(tile))
	_lay_the_sielzug(world, site, plan, generator)
	for field in plan.fields:
		_lay_field_boundary(world, site, plan, field)
	for fence in plan.fences:
		for tile in plan.ring_tiles(fence):
			_put(world, VillagePlan.RING_OBJECTS[fence["kind"]], site.to_world(tile))
	for group in plan.objects:
		for tile: Vector2i in group["tiles"]:
			_put(world, group["type"], site.to_world(tile))
	if with_buildings:
		refusal = _put_up_buildings(world, site, plan)
	for coords in loaded:
		world.remove_chunk(coords)
	return refusal


## Gives the tiles of the way from the camp to the village (`VillageSite.camp_way`) the wear of a
## path, where the ground wears: a track that finds the village for the player. It is plain desire
## path wear, so it fades to grass in about ten days unless it is walked (see desire-paths.md).
static func lay_track(world: World, site: VillageSite) -> void:
	var generator := WorldGenerator.new(world.world_seed)
	var loaded: Array[Vector2i] = []
	var most_days := PathRules.default_rules().most_days()
	for tile in site.camp_way:
		var coords := Chunk.world_to_chunk(tile)
		if not world.is_chunk_loaded(coords):
			world.add_chunk(generator.generate_chunk(coords))
			loaded.append(coords)
		world.set_wear_days(tile, most_days)
	for coords in loaded:
		world.remove_chunk(coords)


## Puts up the buildings of the plan and makes the record of the village. Returns why a building
## could not stand, or "".
static func _put_up_buildings(world: World, site: VillageSite, plan: VillagePlan) -> String:
	var village := Village.new()
	village.village_name = plan.village_name
	village.area = site.land(plan)
	village.meeting_spot = site.to_world(plan.meeting_spot)
	village.square = Rect2i(site.to_world(plan.square.position), plan.square.size)
	village.mill_spot = Rect2i(site.to_world(plan.mill_spot.position), plan.mill_spot.size)
	for field in plan.fields:
		village.field_spots.append(site.to_world(plan.field_spot(field)))
	for entry in plan.buildings:
		var origin := site.to_world(entry["origin"])
		if world.place_building(entry["type"], origin, entry["style"]) == null:
			return "%s can't stand at %s" % [entry["id"], origin]
		village.building_origins.append(origin)
	_lay_cobbles(world, site, plan)
	world.village = village
	return ""


## Lays a cobble on every tile of the lanes and the square that is free: not under a building, a
## well or a fence, and ground a cobble can be laid on (a lane over the Sielzug is a culvert, which
## is land). The cobbles are the village's own (see `World.is_village_cobble`).
static func _lay_cobbles(world: World, site: VillageSite, plan: VillagePlan) -> void:
	var plan_tiles := plan.all_lane_tiles()
	for v in range(plan.square.position.y, plan.square.end.y):
		for u in range(plan.square.position.x, plan.square.end.x):
			plan_tiles[Vector2i(u, v)] = true
	var cobble_terrains: Array = WorldObjectTypes.TYPES[WorldObjectTypes.STONE_PATH]["placed_on"]
	for plan_tile in plan_tiles:
		var tile := site.to_world(plan_tile)
		if cobble_terrains.any(
			func(terrain: Tile.Terrain) -> bool: return world.is_free_on(tile, terrain)
		):
			_put(world, WorldObjectTypes.STONE_PATH, tile)


## Why the village can't be built on this land, or "" if it can.
static func _refusal(world: World, land: Rect2i) -> String:
	for building in world.buildings():
		if building.tiles().any(land.has_point):
			return "a building stands on the village's land at %s" % building.origin
	for object in world.edited_objects():
		if land.has_point(object.pos):
			return "something was changed on the village's land at %s" % object.pos
	for tile in world.tilled_tiles():
		if land.has_point(tile):
			return "the village's land is tilled at %s" % tile
	return ""


## Loads the chunks of the land that are not loaded, with the edits replayed on them, and returns
## their coordinates, to be unloaded again when the work there is done (the streaming loads what
## the player is near).
static func load_chunks(world: World, generator: WorldGenerator, land: Rect2i) -> Array[Vector2i]:
	var loaded: Array[Vector2i] = []
	var first := Chunk.world_to_chunk(land.position)
	var last := Chunk.world_to_chunk(land.end - Vector2i.ONE)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var coords := Vector2i(x, y)
			if not world.is_chunk_loaded(coords):
				world.add_chunk(generator.generate_chunk(coords))
				loaded.append(coords)
	return loaded


## The ground from `inland_from_u` on is dry and clean: wetland is drained, and what grew or lay
## there (trees, bushes, stones, tall grass, reeds) is felled, bar the sea dyke.
static func _clear_inland(world: World, site: VillageSite, plan: VillagePlan) -> void:
	var inland := Rect2i(
		site.to_world(Vector2i(plan.inland_from_u, plan.area.position.y)),
		Vector2i(plan.area.end.x - plan.inland_from_u, plan.area.size.y)
	)
	for y in range(inland.position.y - BIG_OBJECT_REACH.y, inland.end.y):
		for x in range(inland.position.x - BIG_OBJECT_REACH.x, inland.end.x):
			var tile := Vector2i(x, y)
			var chunk := world.chunk_at(Chunk.world_to_chunk(tile))
			var object := chunk.object_at(Chunk.local_pos(tile))
			if (
				object != null
				and not KEPT_WHEN_CLEARING.has(object.type)
				and object.tiles().any(inland.has_point)
			):
				world.take_off(object)
			if inland.has_point(tile) and world.tile_at(tile).terrain == Tile.Terrain.WETLAND:
				world.set_terrain(tile, Tile.Terrain.GRASS)


## The Sielzug runs from the dyke to its end, through a gap in the dyke: row by row from the
## row's own first tile of land, as the coast wanders. A lane over it is a culvert (the plan leaves
## those tiles out).
static func _lay_the_sielzug(
	world: World, site: VillageSite, plan: VillagePlan, generator: WorldGenerator
) -> void:
	var lane_tiles := plan.all_lane_tiles()
	for v in range(plan.siel.position.y, plan.siel.end.y):
		var row := site.origin.y + v
		for x in range(generator.first_land_x(row), site.origin.x + plan.siel.end.x):
			if not lane_tiles.has(Vector2i(x - site.origin.x, v)):
				_lay_water(world, Vector2i(x, row))


## A field's boundary is a ditch on the marsh and a Knick beyond it.
static func _lay_field_boundary(
	world: World, site: VillageSite, plan: VillagePlan, field: Dictionary
) -> void:
	for tile in plan.ring_tiles(field):
		if tile.x <= plan.marsh_end_u:
			_lay_water(world, site.to_world(tile))
		else:
			_put(world, WorldObjectTypes.KNICK, site.to_world(tile))


## Water where there was land, and nothing standing in it (the dyke at the Sielzug's gap).
static func _lay_water(world: World, tile: Vector2i) -> void:
	world.remove_object(tile)
	world.set_terrain(tile, Tile.Terrain.WATER)


static func _put(world: World, type: StringName, tile: Vector2i) -> void:
	world.add_object(WorldObject.new(type, tile))
