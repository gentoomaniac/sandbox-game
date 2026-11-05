class_name GameState
extends RefCounted
## Everything that makes up one game: the world, the clock and the player. Plain state with
## no rendering or input; scenes read it and send it actions such as `sleep_in`.
##
## The player is on one map at a time: the world, or the interior of a building. The world
## stays as it is while they are inside.

## What the use action does on a tile.
enum Use { NOTHING, TILL, PLANT, HARVEST, INVENTORY_FULL }

const CROP := WorldObjectTypes.TURNIP
## What harvesting a crop gives: the crop, and one seed back (until a shop sells seeds).
const HARVEST_YIELD := {ItemTypes.TURNIP: 1, ItemTypes.TURNIP_SEEDS: 1}
## How close (in tiles, diagonals included) the player must be to a bed to sleep in it.
const BED_REACH := 1

var world: World
var clock := GameClock.new()
var player := PlayerState.new()
## Where the player is: `world`, or the interior of `_building_inside`.
var current_map: GameMap

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
	state.player.inventory = Inventory.with_starting_items()
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


## What `use` would do on a tile of the world (nothing inside) with the held item: a hoe
## tills grass, seeds plant on soil, an empty hand harvests a ripe crop. Other tools do nothing
## yet.
func use_at(world_pos: Vector2i) -> Use:
	if is_inside():
		return Use.NOTHING
	var held := player.inventory.held_item()
	if held == ItemTypes.NONE:
		var object := world.object_at(world_pos)
		return Use.HARVEST if object != null and object.is_ripe() else Use.NOTHING
	var item: Dictionary = ItemTypes.TYPES[held]
	if item.has("plants") and world.is_plantable(world_pos):
		return Use.PLANT
	if item.get("tool") == ItemTypes.HOE and world.is_tillable(world_pos):
		return Use.TILL
	return Use.NOTHING


## Whether the held item does anything anywhere, so it is worth highlighting a target.
func can_use_held_item() -> bool:
	var held := player.inventory.held_item()
	if held == ItemTypes.NONE:
		return true
	var item: Dictionary = ItemTypes.TYPES[held]
	return item.has("plants") or item.get("tool") == ItemTypes.HOE


## Uses a tile (see `use_at`) and returns what was done. A harvest that doesn't fit in the
## inventory is not done: INVENTORY_FULL.
func use_tile(target: Vector2i) -> Use:
	var use := use_at(target)
	match use:
		Use.TILL:
			world.set_terrain(target, Tile.Terrain.SOIL)
		Use.PLANT:
			var seeds := player.inventory.held_item()
			world.add_object(WorldObject.new(ItemTypes.TYPES[seeds]["plants"], target))
			player.inventory.remove(seeds, 1)
		Use.HARVEST:
			if not player.inventory.can_add(HARVEST_YIELD):
				return Use.INVENTORY_FULL
			world.remove_object(target)
			for item: StringName in HARVEST_YIELD:
				player.inventory.add(item, HARVEST_YIELD[item])
	return use


## Uses the tile the player faces.
func use_facing_tile() -> Use:
	return use_tile(player.facing_tile())


## Maps are saved as references, never as copies: `{"kind": "world"}`, or
## `{"kind": "interior", "building": [x, y]}` for the interior of the building with that
## origin. So the current map and the home map stay the very objects they point at.
func to_dict() -> Dictionary:
	return {
		"world": world.to_dict(),
		"clock": clock.to_dict(),
		"player": player.to_dict(),
		"current_map": _map_to_ref(current_map),
		"home_map": _map_to_ref(player.home_map),
	}


## The chunks of the restored world are not loaded yet: whoever shows it streams them in.
static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.world = World.from_dict(data["world"])
	state.clock = GameClock.from_dict(data["clock"])
	state.clock.new_day.connect(state._on_new_day)
	state.player = PlayerState.from_dict(data["player"], state._map_from_ref(data["home_map"]))
	state.current_map = state._map_from_ref(data["current_map"])
	state._building_inside = state._building_of_ref(data["current_map"])
	return state


func _map_to_ref(map: GameMap) -> Dictionary:
	if map == world:
		return {"kind": "world"}
	for building in world.buildings():
		if building.interior == map:
			return {"kind": "interior", "building": SaveCodec.vector_to_json(building.origin)}
	assert(false, "A map that belongs to no building")
	return {}


func _map_from_ref(ref: Dictionary) -> GameMap:
	var building := _building_of_ref(ref)
	return world if building == null else building.interior


## The building whose interior the reference names, or null for the world.
func _building_of_ref(ref: Dictionary) -> Building:
	if ref["kind"] == "world":
		return null
	var origin := SaveCodec.vector_from_json(ref["building"])
	for building in world.buildings():
		if building.origin == origin:
			return building
	assert(false, "No building at %s" % origin)
	return null


func _on_new_day(_day: int) -> void:
	world.grow_crops()


func _tile_centre(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func _distance_to_player(object: WorldObject) -> float:
	return (Vector2(object.pos) + Vector2(0.5, 0.5)).distance_to(player.position)
