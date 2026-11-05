class_name GameState
extends RefCounted
## Everything that makes up one game: the world, the clock and the player. Plain state with
## no rendering or input; scenes read it and send it actions such as `sleep_in`.
##
## The player is on one map at a time: the world, or the interior of a building. The world
## stays as it is while they are inside.

## What the use action does on a tile. HARVEST is a ripe crop, FORAGE something a hand picks
## (a bush, a fern), HIT a tool cut or mined at an object, NEEDS_BETTER_TOOL a tool that is too
## weak for the object.
enum Use { NOTHING, TILL, PLANT, HARVEST, FORAGE, HIT, NEEDS_BETTER_TOOL, INVENTORY_FULL }

## The tools the use action has something to do with.
const ACTIVE_TOOLS := [ItemTypes.HOE, ItemTypes.AXE, ItemTypes.PICKAXE]
const CROP := WorldObjectTypes.TURNIP
## What harvesting a crop gives: the crop, and one seed back (until a shop sells seeds).
const HARVEST_YIELD := {ItemTypes.TURNIP: 1, ItemTypes.TURNIP_SEEDS: 1}
## The energy rule (see EnergyRules `cost_of`) for each use that costs energy. The others
## (nothing done, too weak a tool, full inventory) cost nothing.
const COST_KINDS := {
	Use.TILL: &"till",
	Use.PLANT: &"plant",
	Use.HARVEST: &"pick",
	Use.FORAGE: &"pick",
	Use.HIT: &"hit",
}
## Passing out wakes the player at this time of day, in the home bed.
const WAKE_UP_MINUTE := 6 * GameClock.MINUTES_PER_HOUR
## How close (in tiles, diagonals included) the player must be to a bed to sleep in it.
const BED_REACH := 1

var world: World
var clock := GameClock.new()
var player := PlayerState.new()
var energy_rules := EnergyRules.default_rules()
## What every use costs is multiplied by this (the Game setting: 0.5, 1 or 1.5).
var energy_drain := 1.0
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


## Sleeps through the bed's fixed sleep time, makes it home and fills energy and health as
## far as the bed does (and a debuff still allows).
func sleep_in(bed: WorldObject) -> void:
	assert(bed.sleep_minutes() > 0, "Not a bed: %s" % bed.type)
	clock.advance(bed.sleep_minutes())
	player.home_map = current_map
	player.home_bed = bed.pos
	var fill := energy_rules.sleep_fill(bed.type)
	player.energy = minf(maxf(player.energy, fill), energy_cap())
	player.health = maxf(player.health, fill)


## The most energy the player can have now.
func energy_cap() -> float:
	return energy_rules.debuff_energy_max() if player.is_debuffed else PlayerState.MAX_ENERGY


## How fast the player walks, as a fraction of full speed: the slowest of what low energy and
## a debuff allow.
func walk_speed_factor() -> float:
	var factor := energy_rules.walk_factor(player.energy)
	if player.is_debuffed:
		factor = minf(factor, energy_rules.debuff_walk_factor())
	return factor


## Eats one of the held food, on any map: it restores energy up to the cap. Does nothing, and
## returns false, unless the held item is food and the energy is below the cap.
func eat_held() -> bool:
	var food := player.inventory.held_item()
	if not energy_rules.is_food(food) or player.energy >= energy_cap():
		return false
	player.inventory.remove(food, 1)
	player.energy = minf(player.energy + energy_rules.food_restore(food), energy_cap())
	return true


func is_out_of_energy() -> bool:
	return player.energy <= 0.0


## The player passes out: time jumps to the next 06:00, they wake in the home bed with the
## debuff of that day (it ends at the next new day) and no items lost.
func pass_out() -> void:
	var minutes := posmod(WAKE_UP_MINUTE - clock.minute_of_day, GameClock.MINUTES_PER_DAY)
	# Passing out at 06:00 sharp wakes at 06:00 the next day, not at once.
	clock.advance(minutes if minutes > 0 else GameClock.MINUTES_PER_DAY)
	current_map = player.home_map
	_building_inside = _building_with_interior(current_map)
	player.position = _tile_centre(_wake_up_tile())
	player.is_debuffed = true
	player.energy = energy_rules.debuff_energy_max()
	player.health = energy_rules.debuff_health()


## What `use` would do on a tile of the world (nothing inside) with the held item: a hoe
## tills grass, seeds plant on soil and a sapling on grass, an empty hand harvests a ripe crop
## or picks a bush, an axe or pickaxe hits what it cuts or mines.
func use_at(world_pos: Vector2i) -> Use:
	if is_inside():
		return Use.NOTHING
	var object := world.object_at(world_pos)
	var held := player.inventory.held_item()
	if held == ItemTypes.NONE:
		return _use_by_hand(object)
	var item: Dictionary = ItemTypes.TYPES[held]
	if item.has("plants") and world.is_free_on(world_pos, item.get("plants_on", Tile.Terrain.SOIL)):
		return Use.PLANT
	if item.get("tool") == ItemTypes.HOE and world.is_free_on(world_pos, Tile.Terrain.GRASS):
		return Use.TILL
	return _use_tool(item, object)


## Whether the held item does anything anywhere, so it is worth highlighting a target.
func can_use_held_item() -> bool:
	var held := player.inventory.held_item()
	if held == ItemTypes.NONE:
		return true
	var item: Dictionary = ItemTypes.TYPES[held]
	return item.has("plants") or ACTIVE_TOOLS.has(item.get("tool"))


## Uses a tile (see `use_at`) and returns what was done, which costs energy (more the
## heavier the load). A use with too little energy left still happens; the energy ends at 0
## (see `is_out_of_energy`). A harvest, pick or final hit whose drops don't fit in the
## inventory is not done: INVENTORY_FULL.
func use_tile(target: Vector2i) -> Use:
	var weight_factor := energy_rules.weight_factor(player.inventory.total_weight())
	var use := _do_use(target)
	if COST_KINDS.has(use):
		var cost := energy_rules.cost_of(COST_KINDS[use]) * weight_factor * energy_drain
		player.energy = maxf(0.0, player.energy - cost)
	return use


func _do_use(target: Vector2i) -> Use:
	var use := use_at(target)
	match use:
		Use.TILL:
			world.set_terrain(target, Tile.Terrain.SOIL)
		Use.PLANT:
			var seeds := player.inventory.held_item()
			var planted := WorldObject.new(ItemTypes.TYPES[seeds]["plants"], target)
			planted.state = ItemTypes.TYPES[seeds].get("plants_state", {}).duplicate()
			world.add_object(planted)
			player.inventory.remove(seeds, 1)
		Use.HARVEST:
			if not player.inventory.can_add(HARVEST_YIELD):
				return Use.INVENTORY_FULL
			world.remove_object(target)
			for item: StringName in HARVEST_YIELD:
				player.inventory.add(item, HARVEST_YIELD[item])
		Use.FORAGE:
			var plant := world.object_at(target)
			var drops: Dictionary = plant.type_data()["drops"]
			if not player.inventory.can_add(drops):
				return Use.INVENTORY_FULL
			_take_drops(drops)
			if plant.type_data().has("regrow_days"):
				plant.pick()
				world.change_object(plant)
			else:
				world.remove_object(target)
		Use.HIT:
			return _hit(world.object_at(target))
	return use


func _use_tool(tool_item: Dictionary, object: WorldObject) -> Use:
	if object == null or object.type_data().get("tool", ItemTypes.NONE) != tool_item.get("tool"):
		return Use.NOTHING
	if tool_item["level"] >= object.type_data()["harvest_level"]:
		return Use.HIT
	return Use.NEEDS_BETTER_TOOL


func _use_by_hand(object: WorldObject) -> Use:
	if object == null:
		return Use.NOTHING
	if object.is_ripe():
		return Use.HARVEST
	return Use.FORAGE if object.is_forageable() else Use.NOTHING


## Hits an object with the held tool. The hit that finishes it gives its drops and leaves
## what it leaves; it is not done if the drops don't fit.
func _hit(object: WorldObject) -> Use:
	var power := ItemTypes.tool_power(player.inventory.held_item())
	if not object.is_finished_by(power):
		world.hit_object(object, power)
		return Use.HIT
	var object_type := object.type_data()
	var drops: Dictionary = object_type["drops"].duplicate()
	if _rolls_sapling(object):
		drops[ItemTypes.SAPLING] = 1
	if not player.inventory.can_add(drops):
		return Use.INVENTORY_FULL
	_take_drops(drops)
	if not object_type.has("leaves"):
		world.remove_object(object.pos)
	else:
		var stump := WorldObject.new(object_type["leaves"], object.pos)
		if object_type.get("regrows", false):
			stump.state["tree"] = str(object.type)
		world.replace_object(object, stump)
	return Use.HIT


## Whether felling this tree today also gives a sapling. The same tree on the same day always
## rolls the same.
func _rolls_sapling(tree: WorldObject) -> bool:
	return (
		PositionHash.of(tree.pos, clock.day) % 100
		< tree.type_data().get("sapling_chance", 0.0) * 100
	)


func _take_drops(drops: Dictionary) -> void:
	for item: StringName in drops:
		player.inventory.add(item, drops[item])


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
	player.is_debuffed = false
	# A stump or sapling doesn't grow into a tree under the player's feet.
	var occupied: Array[Vector2i] = []
	if not is_inside():
		occupied.append(player.tile())
	world.pass_night(occupied)


## The building whose interior this is, or null for the world.
func _building_with_interior(map: GameMap) -> Building:
	for building in world.buildings():
		if building.interior == map:
			return building
	return null


## Where the player stands when they wake: on the bed, or beside it if the bed blocks walking.
func _wake_up_tile() -> Vector2i:
	var candidates: Array[Vector2i] = [player.home_bed]
	for y in range(-1, 2):
		for x in range(-1, 2):
			candidates.append(player.home_bed + Vector2i(x, y))
	for tile in candidates:
		if PlayerState.can_stand_at(current_map, _tile_centre(tile)):
			return tile
	return player.home_bed


func _tile_centre(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func _distance_to_player(object: WorldObject) -> float:
	return (Vector2(object.pos) + Vector2(0.5, 0.5)).distance_to(player.position)
