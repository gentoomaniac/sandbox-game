class_name GameState
extends RefCounted
## Everything that makes up one game: the world, the clock and the player. Plain state with
## no rendering or input; scenes read it and send it actions such as `sleep_in`.
##
## The player is on one map at a time: the world, or the interior of a building. The world
## stays as it is while they are inside.

## What the use action does on a tile.
enum Use { NOTHING, TILL, PLANT, HARVEST }

const CROP := WorldObjectTypes.TURNIP
## How close (in tiles, diagonals included) the player must be to a bed to sleep in it.
const BED_REACH := 1

var world: World
var clock := GameClock.new()
var player := PlayerState.new()
## Where the player is: `world`, or the interior of `_building_inside`.
var current_map: GameMap

## Crops harvested so far; there is no inventory yet.
var harvest_count := 0
var _building_inside: Building


func _init() -> void:
	clock.new_day.connect(_on_new_day)


## A new game: the player starts at a camp site near the world centre, with home set to its
## sleeping bag. The chunks around the camp are generated into the world here.
static func new_game(world_seed: int) -> GameState:
	var state := GameState.new()
	state.world = World.new(world_seed)
	state.current_map = state.world
	var camp := CampSite.create(state.world, WorldGenerator.new(world_seed))
	state.player.position = Vector2(camp.spawn_pos) + Vector2(0.5, 0.5)
	state.player.home_map = state.world
	state.player.home_bed = camp.sleeping_bag_pos
	return state


func is_inside() -> bool:
	return _building_inside != null


## Whether the player stands on a tile that leads to another map: the door of a building in
## the world, or the exit of the interior they are in.
func door_underfoot() -> bool:
	var tile := player.tile()
	if is_inside():
		return tile == _building_inside.interior.exit_tile
	var building := world.building_at(tile)
	return building != null and building.door_tile() == tile


## Takes the player through the door under their feet: into the building (making its interior
## the first time), or out to the tile in front of its door.
func pass_door() -> void:
	assert(door_underfoot(), "No door under the player")
	if is_inside():
		player.position = _tile_centre(_building_inside.door_tile() + Vector2i.DOWN)
		_building_inside = null
		current_map = world
		return
	_building_inside = world.building_at(player.tile())
	if _building_inside.interior == null:
		var map_path: String = BuildingTypes.TYPES[_building_inside.type]["interior_map"]
		_building_inside.interior = InteriorLoader.load_interior(map_path)
	current_map = _building_inside.interior
	player.position = _tile_centre(_building_inside.interior.entry_tile())


## The nearest bed the player can reach, or null. Their own tile counts.
func bed_in_reach() -> WorldObject:
	var player_tile := player.tile()
	var nearest: WorldObject = null
	for y in range(-BED_REACH, BED_REACH + 1):
		for x in range(-BED_REACH, BED_REACH + 1):
			var object := current_map.object_at(player_tile + Vector2i(x, y))
			if object == null or object.sleep_minutes() == 0:
				continue
			if nearest == null or _distance_to_player(object) < _distance_to_player(nearest):
				nearest = object
	return nearest


## Sleeps through the bed's fixed sleep time, and makes it home.
func sleep_in(bed: WorldObject) -> void:
	assert(bed.sleep_minutes() > 0, "Not a bed: %s" % bed.type)
	clock.advance(bed.sleep_minutes())
	player.home_map = current_map
	player.home_bed = bed.pos


## What `use` would do on a tile of the world (nothing inside): harvest a ripe crop, plant on
## soil, till grass.
func use_at(world_pos: Vector2i) -> Use:
	if is_inside():
		return Use.NOTHING
	var object := world.object_at(world_pos)
	if object != null:
		return Use.HARVEST if object.is_ripe() else Use.NOTHING
	if world.is_plantable(world_pos):
		return Use.PLANT
	if world.is_tillable(world_pos):
		return Use.TILL
	return Use.NOTHING


## Uses the tile the player faces (see `use_at`) and returns what was done.
func use_facing_tile() -> Use:
	var target := player.facing_tile()
	var use := use_at(target)
	match use:
		Use.TILL:
			world.set_terrain(target, Tile.Terrain.SOIL)
		Use.PLANT:
			world.add_object(WorldObject.new(CROP, target))
		Use.HARVEST:
			world.remove_object(target)
			harvest_count += 1
	return use


func _on_new_day(_day: int) -> void:
	world.grow_crops()


func _tile_centre(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func _distance_to_player(object: WorldObject) -> float:
	return (Vector2(object.pos) + Vector2(0.5, 0.5)).distance_to(player.position)
