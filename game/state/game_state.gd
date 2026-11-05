class_name GameState
extends RefCounted
## Everything that makes up one game: the world, the clock and the player. Plain state with
## no rendering or input; scenes read it and send it actions such as `sleep_in`.
##
## The player is on one map at a time: the world, or the interior of a building. The world
## stays as it is while they are inside.

## What the use action does on a tile. HARVEST is a ripe crop, FORAGE something a hand picks
## (a bush, a fern), CLEAR a dead crop that a hand pulls up, WATER a watering can wetting tilled
## soil, HIT a tool cut or mined at an object, NEEDS_BETTER_TOOL a tool that is too weak for the
## object, MOW a scythe cutting the tall grass and reeds around the target, DIG a shovel in grass
## (which may find clay), PLACE an item that puts an object down (a chest), TAKE_DOWN an axe taking
## a chest down inside a house (outdoors it is a HIT), NO_ROOM that, with too little room in the
## inventory for the chest and what it holds. What a harvest, a pick or a final hit gives lies on
## the ground (see World `drop_items`).
enum Use {
	NOTHING,
	TILL,
	PLANT,
	HARVEST,
	FORAGE,
	HIT,
	NEEDS_BETTER_TOOL,
	CLEAR,
	WATER,
	MOW,
	DIG,
	PLACE,
	TAKE_DOWN,
	NO_ROOM,
}

## The tools the use action has something to do with.
const ACTIVE_TOOLS := [
	ItemTypes.HOE,
	ItemTypes.AXE,
	ItemTypes.PICKAXE,
	ItemTypes.WATERING_CAN,
	ItemTypes.SCYTHE,
	ItemTypes.SHOVEL,
]
## The energy rule (see EnergyRules `cost_of`) for each use that costs energy. The others
## (nothing done, too weak a tool) cost nothing.
const COST_KINDS := {
	Use.TILL: &"till",
	Use.PLANT: &"plant",
	Use.HARVEST: &"pick",
	Use.FORAGE: &"pick",
	Use.CLEAR: &"pick",
	Use.WATER: &"water",
	Use.HIT: &"hit",
	Use.MOW: &"mow",
	Use.DIG: &"dig",
}
## Digging a clay spot gives this much clay, with this chance (rolled once per spot and day).
const CLAY_DIG_YIELD := {ItemTypes.CLAY: 2}
const CLAY_DIG_CHANCE := 0.4
## Sleeping and passing out wake the player the next time the clock shows this.
const WAKE_UP_MINUTE := 6 * GameClock.MINUTES_PER_HOUR + 30
## Passing out sleeps at least this long, even when the morning comes sooner.
const PASS_OUT_MINUTES := 10 * GameClock.MINUTES_PER_HOUR
## A player who is still awake when the clock shows this has stayed up too late and passes out.
const LATE_NIGHT_MINUTE := 1 * GameClock.MINUTES_PER_HOUR
## Items on the ground within this many tiles of the player (their feet) are pulled to them.
const PULL_RADIUS := 0.5
## How fast a pulled item moves, in tiles per second: faster than the player walks, so it
## catches up.
const PULL_SPEED := 8.0
## A pulled item that is this close is picked up.
const PICKUP_RADIUS := 0.15

var world: World
var clock := GameClock.new()
## Where the sun is over the year; the weather follows it.
var sun := Sun.new()
## Built from the world seed (see `new_game` and `from_dict`).
var weather: Weather
## Session-only (see Console): the weather condition that is forced, or &"" for the weather
## as the simulation has it. Not saved.
var weather_override := &""
## The snow on the ground, from the weather (see SnowCover); built with `weather`.
var snow_cover: SnowCover
var player := PlayerState.new()
var energy_rules := EnergyRules.default_rules()
## What every use costs is multiplied by this (the Game setting: 0.5, 1 or 1.5).
var energy_drain := 1.0
## Session-only cheats (see Console): not saved.
var cheats := CheatFlags.new()
## The player was awake when the clock reached LATE_NIGHT_MINUTE (see `pass_awake_time`) and has
## not slept since: they pass out. Not saved.
var is_up_too_late := false
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
	state.world.clock = state.clock
	state.weather = Weather.new(world_seed, state.sun)
	state.snow_cover = SnowCover.new(state.weather)
	state.current_map = state.world
	var camp := CampSite.create(state.world, WorldGenerator.new(world_seed))
	state.player.position = Vector2(camp.spawn_pos) + Vector2(0.5, 0.5)
	state.player.home_map = state.world
	state.player.home_bed = camp.sleeping_bag_pos
	state.player.inventory = Inventory.with_starting_items()
	state.player.equipment = Equipment.with_starting_outfit()
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
	return Interaction.nearest_in_reach(
		self, func(object: WorldObject) -> bool: return object.is_bed()
	)


## Sleeps until the next morning (WAKE_UP_MINUTE), makes the bed home and fills energy and
## health as far as the bed does (and a debuff still allows).
func sleep_in(bed: WorldObject) -> void:
	assert(bed.is_bed(), "Not a bed: %s" % bed.type)
	clock.advance(clock.minutes_until(WAKE_UP_MINUTE))
	is_up_too_late = false
	player.home_map = current_map
	player.home_bed = bed.pos
	var fill := energy_rules.sleep_fill(bed.type)
	player.energy = minf(maxf(player.energy, fill), energy_cap())
	player.health = maxf(player.health, fill)


## The weather the player sees: at their tile, or outside the door of the house they are in
## (they would see it through its windows). A forced condition (see Console) replaces the
## simulated one.
func current_weather() -> WeatherSample:
	var sample := weather.at(_outdoor_tile(), clock.day, clock.minute_of_day)
	return sample if weather_override == &"" else weather.forced(sample, weather_override)


## The snow on the ground where the player is (or outside the house they are in), 0 to 1, as
## of the start of the hour: the look of the world only follows it hour by hour.
func current_snow_cover() -> float:
	return snow_cover.at(_outdoor_tile(), clock.day, _hour_start())


## The frost on the ground where the player is, 0 to 1, as of the start of the hour.
func current_frost() -> float:
	return snow_cover.frost_at(weather.at(_outdoor_tile(), clock.day, _hour_start()).temperature)


## The tile whose weather the player sees: theirs, or outside the door of the house they are in.
func _outdoor_tile() -> Vector2i:
	return _building_inside.door_tile() if is_inside() else player.tile()


func _hour_start() -> int:
	return clock.minute_of_day / GameClock.MINUTES_PER_HOUR * GameClock.MINUTES_PER_HOUR


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


## Lets time pass while the player is awake. Reaching LATE_NIGHT_MINUTE means they have stayed
## up too late (`is_up_too_late`).
func pass_awake_time(minutes: int) -> void:
	if minutes >= clock.minutes_until(LATE_NIGHT_MINUTE):
		is_up_too_late = true
	clock.advance(minutes)


## The player passes out: they sleep until the next morning (WAKE_UP_MINUTE) but at least
## PASS_OUT_MINUTES, and wake in the home bed with the debuff of that day (it ends at the next
## new day) and no items lost. Returns how many minutes they slept.
func pass_out() -> int:
	var minutes := maxi(clock.minutes_until(WAKE_UP_MINUTE), PASS_OUT_MINUTES)
	clock.advance(minutes)
	is_up_too_late = false
	current_map = player.home_map
	_building_inside = _building_with_interior(current_map)
	player.position = _tile_centre(_wake_up_tile())
	player.is_debuffed = true
	player.energy = energy_rules.debuff_energy_max()
	if not cheats.is_god:
		player.health = energy_rules.debuff_health()
	return minutes


## What `use` would do on a tile with the held item: a hoe tills grass, crop seeds plant on soil
## and tree seeds on grass, a watering can wets dry tilled soil, an empty hand harvests a ripe crop,
## clears a dead one or picks a bush, an axe or pickaxe hits what it cuts or mines, a scythe mows if
## there is tall grass or reeds in its reach, a shovel digs in any free grass (the player can't tell
## a clay spot from the cursor), and an item that places an object puts it on a free tile. Inside,
## only placing and taking a chest down are possible.
func use_at(pos: Vector2i) -> Use:
	var held := player.inventory.held_item()
	if held == ItemTypes.NONE:
		return Use.NOTHING if is_inside() else _use_by_hand(world.object_at(pos))
	var item: Dictionary = ItemTypes.TYPES[held]
	if item.has("places") and _can_place_on(pos):
		return Use.PLACE
	if is_inside():
		return _use_inside(item, pos)
	if item.has("plants") and world.is_free_on(pos, item.get("plants_on", Tile.Terrain.SOIL)):
		return Use.PLANT
	return _use_tool(item, world.object_at(pos), pos)


## Whether the held item does anything anywhere, so it is worth highlighting a target.
func can_use_held_item() -> bool:
	var held := player.inventory.held_item()
	if held == ItemTypes.NONE:
		return true
	var item: Dictionary = ItemTypes.TYPES[held]
	return item.has("plants") or item.has("places") or ACTIVE_TOOLS.has(item.get("tool"))


## Uses a tile (see `use_at`) and returns what was done, which costs energy (more the
## heavier the load, unless a cheat says otherwise). A use with too little energy left still
## happens; the energy ends at 0 (see `is_out_of_energy`).
func use_tile(target: Vector2i) -> Use:
	var weight_factor := 1.0
	if not cheats.is_weight_off:
		weight_factor = energy_rules.weight_factor(player.carried_weight())
	var drain := 0.0 if cheats.is_drain_off else energy_drain
	var use := _do_use(target)
	if COST_KINDS.has(use):
		var cost := energy_rules.cost_of(COST_KINDS[use]) * weight_factor * drain
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
			var crop := world.object_at(target)
			if CropLife.regrows(crop):
				CropLife.regrow(crop)
				world.change_object(crop)
			else:
				world.remove_object(target)
			world.drop_items(target, CropLife.harvest_of(crop))
		Use.CLEAR:
			world.remove_object(target)
		Use.WATER:
			world.set_moisture(target, 1.0)
		Use.FORAGE:
			var plant := world.object_at(target)
			if plant.type_data().has("regrow_days"):
				plant.pick()
				world.change_object(plant)
			else:
				world.remove_object(target)
			world.drop_items(target, plant.picked_drops())
		Use.MOW:
			for plant in _plants_to_mow(target):
				plant.pick()
				world.change_object(plant)
				world.drop_items(plant.pos, plant.picked_drops())
		Use.DIG:
			_dig(target)
		Use.PLACE:
			var held := player.inventory.held_item()
			current_map.add_object(WorldObject.new(ItemTypes.TYPES[held]["places"], target))
			player.inventory.remove(held, 1)
		Use.TAKE_DOWN:
			var items := _items_of_chest(current_map.remove_object(target))
			for item: StringName in items:
				player.inventory.add(item, items[item])
		Use.HIT:
			return _hit(world.object_at(target))
	return use


## The 4 tiles one swing of the scythe mows, aimed at `target`: it, the tile beyond it in the
## facing direction and the tiles left and right of `target`.
func _mow_tiles(target: Vector2i) -> Array[Vector2i]:
	var facing := player.facing
	var sideways := Vector2i(absi(facing.y), absi(facing.x))
	return [target, target + facing, target - sideways, target + sideways]


func _plants_to_mow(target: Vector2i) -> Array[WorldObject]:
	var plants: Array[WorldObject] = []
	for tile in _mow_tiles(target):
		var object := world.object_at(tile)
		if object != null and _is_mowable(object):
			plants.append(object)
	return plants


## Whether a scythe can mow the object now: it is something that gets mown and is not mown yet.
func _is_mowable(object: WorldObject) -> bool:
	return object.type_data().get("tool") == ItemTypes.SCYTHE and not object.is_picked()


## Digs the grass at `target`: a clay spot is spent, and gives clay with some chance. Anywhere
## else the shovel finds nothing.
func _dig(target: Vector2i) -> void:
	if not world.has_clay(target):
		return
	world.spend_clay_spot(target)
	if PositionHash.of(target, clock.day) % 100 < CLAY_DIG_CHANCE * 100:
		world.drop_items(target, CLAY_DIG_YIELD)


## Whether the player can put an object on a tile: it is free, and the player's body is not on it
## (they would be stuck in it).
func _can_place_on(pos: Vector2i) -> bool:
	return (
		current_map.is_placeable(pos) and not PlayerState.body_tiles(player.position).has_point(pos)
	)


## What an item does on a tile inside a house, other than placing: an axe takes down a chest.
func _use_inside(item: Dictionary, pos: Vector2i) -> Use:
	var chest := current_map.object_at(pos)
	if chest == null or chest.storage == null or _use_cutting_tool(item, chest) != Use.HIT:
		return Use.NOTHING
	return Use.TAKE_DOWN if player.inventory.can_add(_items_of_chest(chest)) else Use.NO_ROOM


## A chest and what it holds, item id to count: what taking it down gives.
func _items_of_chest(chest: WorldObject) -> Dictionary:
	var items := chest.storage.totals()
	for item: StringName in chest.type_data()["drops"]:
		items[item] = items.get(item, 0) + chest.type_data()["drops"][item]
	return items


## Whether a tile is tilled soil that is not soaked yet. A crop may stand on it.
func _is_dry_soil(world_pos: Vector2i) -> bool:
	var tile := world.tile_at(world_pos)
	return tile != null and tile.terrain == Tile.Terrain.SOIL and world.moisture_at(world_pos) < 1.0


func _use_tool(tool_item: Dictionary, object: WorldObject, world_pos: Vector2i) -> Use:
	var is_grass_free := world.is_free_on(world_pos, Tile.Terrain.GRASS)
	match tool_item.get("tool"):
		ItemTypes.HOE:
			return Use.TILL if is_grass_free else Use.NOTHING
		ItemTypes.WATERING_CAN:
			return Use.WATER if _is_dry_soil(world_pos) else Use.NOTHING
		ItemTypes.SCYTHE:
			return Use.MOW if not _plants_to_mow(world_pos).is_empty() else Use.NOTHING
		ItemTypes.SHOVEL:
			return Use.DIG if is_grass_free else Use.NOTHING
	return _use_cutting_tool(tool_item, object)


## What an axe or a pickaxe does to the object: hit it if it is cut or mined with that tool.
func _use_cutting_tool(tool_item: Dictionary, object: WorldObject) -> Use:
	if object == null or object.type_data().get("tool", ItemTypes.NONE) != tool_item.get("tool"):
		return Use.NOTHING
	if tool_item["level"] >= object.type_data()["harvest_level"]:
		return Use.HIT
	return Use.NEEDS_BETTER_TOOL


func _use_by_hand(object: WorldObject) -> Use:
	if object == null:
		return Use.NOTHING
	if object.is_crop():
		if CropLife.is_dead(object):
			return Use.CLEAR
		return Use.HARVEST if CropLife.is_ripe(object) else Use.NOTHING
	return Use.FORAGE if object.is_forageable() and not world.is_bare(object) else Use.NOTHING


## Hits an object with the held tool. The hit that finishes it leaves what it leaves (a felled
## tree a stump and a trunk, see TrunkPlacement) and drops its drops around it.
func _hit(object: WorldObject) -> Use:
	var power := ItemTypes.tool_power(player.inventory.held_item())
	if not object.is_finished_by(power):
		world.hit_object(object, power)
		return Use.HIT
	var object_type := object.type_data()
	var drops: Dictionary = object_type.get("drops", {}).duplicate()
	if object.storage != null:
		drops = _items_of_chest(object)
	if _rolls_seed(object):
		drops[object_type["seed"]] = 1
	if not object_type.has("leaves"):
		world.remove_object(object.pos)
	else:
		var stump := WorldObject.new(object_type["leaves"], object.pos)
		if object_type.get("regrows", false):
			stump.state["tree"] = str(object.type)
		world.replace_object(object, stump)
		TrunkPlacement.lay(world, object, player.tile())
	world.drop_items(object.pos, drops)
	# The finishing hit replaces or removes the object instead of `hit_object`, which emits
	# this for the other hits; the view still shakes and throws particles for it.
	world.object_hit.emit(object)
	return Use.HIT


## Whether felling this tree today also gives its seed. The same tree on the same day always
## rolls the same.
func _rolls_seed(tree: WorldObject) -> bool:
	return (
		PositionHash.of(tree.pos, clock.day) % 100 < tree.type_data().get("seed_chance", 0.0) * 100
	)


## Pulls the items on the ground near the player towards them and picks up those that
## arrive. What the inventory has no room for stays on the ground, and so do all piles of an
## item while it has no room at all. Does nothing inside a building.
func collect_ground_items(delta: float) -> void:
	if is_inside():
		return
	for ground_item in world.ground_items_near(player.position, PULL_RADIUS):
		if not player.inventory.can_add({ground_item.item: 1}):
			continue
		var to_player := player.position - ground_item.position
		if to_player.length() > maxf(PICKUP_RADIUS, PULL_SPEED * delta):
			ground_item.position += to_player.normalized() * PULL_SPEED * delta
			continue
		ground_item.count = player.inventory.add(ground_item.item, ground_item.count)
		if ground_item.count == 0:
			world.remove_ground_item(ground_item)


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
	state.weather = Weather.new(state.world.world_seed, state.sun)
	state.snow_cover = SnowCover.new(state.weather)
	state.clock = GameClock.from_dict(data["clock"])
	state.clock.new_day.connect(state._on_new_day)
	state.world.clock = state.clock
	state.player = PlayerState.from_dict(data["player"], state._map_from_ref(data["home_map"]))
	state.current_map = state._map_from_ref(data["current_map"])
	state._building_inside = state._building_of_ref(data["current_map"])
	# No sleep wakes between 01:00 and 06:30, so a game saved then was quit by a player who
	# stayed up: they still pass out (`is_up_too_late` itself is not saved).
	var minute := state.clock.minute_of_day
	state.is_up_too_late = minute >= LATE_NIGHT_MINUTE and minute < WAKE_UP_MINUTE
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
	world.pass_night(occupied, weather)


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
