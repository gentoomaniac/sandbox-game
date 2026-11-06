class_name ToolUse
extends RefCounted
## What the use action does: `use_at` says what the held item would do on a tile, `use_tile`
## does it and charges the energy. A hoe tills, an axe hits, a scythe mows: the rules of every
## tool are here. Plain logic on the GameState it is given.

## What the use action does on a tile. HARVEST is a ripe crop, FORAGE something a hand picks
## (a bush, a fern), CLEAR a dead crop that a hand pulls up, WATER a watering can wetting tilled
## soil, HIT a tool cut or mined at an object, NEEDS_BETTER_TOOL a tool that is too weak for the
## object, MOW a scythe cutting the tall grass and reeds around the target, DIG a shovel in grass
## (which may find clay), PLACE an item that puts an object down (a chest, a station), TAKE_DOWN an
## axe or pickaxe taking down what the player placed inside a house (outdoors it is a HIT),
## NO_ROOM that, with too little room in the inventory for it and what it holds. What a harvest,
## a pick or a final hit gives lies on the ground (see World `drop_items`).
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

var _state: GameState


func _init(state: GameState) -> void:
	_state = state


## What `use` would do on a tile with the held item: a hoe tills grass, crop seeds plant on soil
## and tree seeds on grass, a watering can wets dry tilled soil, an empty hand harvests a ripe crop,
## clears a dead one or picks a bush, an axe or pickaxe hits what it cuts or mines, a scythe mows if
## there is tall grass or reeds in its reach, a shovel digs in any free grass (the player can't tell
## a clay spot from the cursor), and an item that places an object puts it on a free tile. Inside,
## only placing and taking a chest down are possible.
func use_at(pos: Vector2i) -> Use:
	var held := _state.player.inventory.held_item()
	if held == ItemTypes.NONE:
		return Use.NOTHING if _state.is_inside() else _use_by_hand(_state.world.object_at(pos))
	var item: Dictionary = ItemTypes.TYPES[held]
	if item.has("places") and _can_place_on(pos, item["places"]):
		return Use.PLACE
	if _state.is_inside():
		return _use_inside(item, pos)
	if (
		item.has("plants")
		and _state.world.is_free_on(pos, item.get("plants_on", Tile.Terrain.SOIL))
	):
		return Use.PLANT
	return _use_tool(item, _state.world.object_at(pos), pos)


## Whether the held item does anything anywhere, so it is worth highlighting a target.
func can_use_held_item() -> bool:
	var held := _state.player.inventory.held_item()
	if held == ItemTypes.NONE:
		return true
	var item: Dictionary = ItemTypes.TYPES[held]
	return item.has("plants") or item.has("places") or ACTIVE_TOOLS.has(item.get("tool"))


## Uses a tile (see `use_at`) and returns what was done, which costs energy (more the
## heavier the load, unless a cheat says otherwise). A use with too little energy left still
## happens; the energy ends at 0 (see `is_out_of_energy`).
func use_tile(target: Vector2i) -> Use:
	var weight_factor := 1.0
	if not _state.cheats.is_weight_off:
		weight_factor = _state.energy_rules.weight_factor(_state.player.carried_weight())
	var drain := 0.0 if _state.cheats.is_drain_off else _state.energy_drain
	var use := _do_use(target)
	if COST_KINDS.has(use):
		var cost := _state.energy_rules.cost_of(COST_KINDS[use]) * weight_factor * drain
		_state.player.energy = maxf(0.0, _state.player.energy - cost)
	return use


func _do_use(target: Vector2i) -> Use:
	var use := use_at(target)
	match use:
		Use.TILL:
			_state.world.set_terrain(target, Tile.Terrain.SOIL)
		Use.PLANT:
			var seeds := _state.player.inventory.held_item()
			var planted := WorldObject.new(ItemTypes.TYPES[seeds]["plants"], target)
			planted.state = ItemTypes.TYPES[seeds].get("plants_state", {}).duplicate()
			_state.world.add_object(planted)
			_state.player.inventory.remove(seeds, 1)
		Use.HARVEST:
			var crop := _state.world.object_at(target)
			if CropLife.regrows(crop):
				CropLife.regrow(crop)
				_state.world.change_object(crop)
			else:
				_state.world.remove_object(target)
			_state.world.drop_items(target, CropLife.harvest_of(crop))
		Use.CLEAR:
			_state.world.remove_object(target)
		Use.WATER:
			_state.world.set_moisture(target, 1.0)
		Use.FORAGE:
			var plant := _state.world.object_at(target)
			if plant.type_data().has("regrow_days"):
				plant.pick()
				_state.world.change_object(plant)
			else:
				_state.world.remove_object(target)
			_state.world.drop_items(target, plant.picked_drops())
		Use.MOW:
			for plant in _plants_to_mow(target):
				plant.pick()
				_state.world.change_object(plant)
				_state.world.drop_items(plant.pos, plant.picked_drops())
		Use.DIG:
			_dig(target)
		Use.PLACE:
			var held := _state.player.inventory.held_item()
			_state.current_map.add_object(WorldObject.new(ItemTypes.TYPES[held]["places"], target))
			_state.player.inventory.remove(held, 1)
		Use.TAKE_DOWN:
			var items := _items_of_placed(_state.current_map.remove_object(target))
			# `use_at` already checked that it all fits (or answered NO_ROOM).
			for item: StringName in items:
				_state.player.inventory.add(item, items[item])
		Use.HIT:
			_hit(_state.world.object_at(target))
	return use


## The 4 tiles one swing of the scythe mows, aimed at `target`: it, the tile beyond it in the
## facing direction and the tiles left and right of `target`.
func _mow_tiles(target: Vector2i) -> Array[Vector2i]:
	var facing := _state.player.facing
	var sideways := Vector2i(absi(facing.y), absi(facing.x))
	return [target, target + facing, target - sideways, target + sideways]


func _plants_to_mow(target: Vector2i) -> Array[WorldObject]:
	var plants: Array[WorldObject] = []
	for tile in _mow_tiles(target):
		var object := _state.world.object_at(tile)
		if object != null and _is_mowable(object):
			plants.append(object)
	return plants


## Whether a scythe can mow the object now: it is something that gets mown and is not mown yet.
func _is_mowable(object: WorldObject) -> bool:
	return object.type_data().get("tool") == ItemTypes.SCYTHE and not object.is_picked()


## Digs the grass at `target`: a clay spot is spent, and gives clay with some chance. Anywhere
## else the shovel finds nothing.
func _dig(target: Vector2i) -> void:
	if not _state.world.has_clay(target):
		return
	_state.world.spend_clay_spot(target)
	if PositionHash.rolls(target, _state.clock.day, CLAY_DIG_CHANCE):
		_state.world.drop_items(target, CLAY_DIG_YIELD)


## Whether the player can put an object of this type on a tile: it is free, the player's body is
## not on it (they would be stuck in it), and the object goes on this map: furniture with only an
## interior picture goes only inside a house, and what is `outdoors_only` only outdoors.
func _can_place_on(pos: Vector2i, placed_type: StringName) -> bool:
	var placed: Dictionary = WorldObjectTypes.TYPES[placed_type]
	var fits_map: bool = (
		not placed.get("outdoors_only", false) if _state.is_inside() else placed.has("atlas_row")
	)
	return (
		fits_map
		and _state.current_map.is_placeable(pos)
		and not PlayerState.body_tiles(_state.player.position).has_point(pos)
	)


## What an item does on a tile inside a house, other than placing: the tool that cuts or breaks
## what the player placed (an axe a chest or a workbench) takes it down. The furniture of the
## house has nothing to drop and stays.
func _use_inside(item: Dictionary, pos: Vector2i) -> Use:
	var placed := _state.current_map.object_at(pos)
	if (
		placed == null
		or not placed.type_data().has("drops")
		or _use_cutting_tool(item, placed) != Use.HIT
	):
		return Use.NOTHING
	var fits := _state.player.inventory.can_add(_items_of_placed(placed))
	return Use.TAKE_DOWN if fits else Use.NO_ROOM


## What the player placed and what it holds (a chest's items, a kiln's load), item id to count:
## what taking it down gives.
func _items_of_placed(placed: WorldObject) -> Dictionary:
	var items := {} if placed.storage == null else placed.storage.totals()
	var now := _state.clock.total_minutes()
	var held := StationWork.contents(placed, now, RecipeRules.default_rules())
	for gives: Dictionary in [held, placed.type_data()["drops"]]:
		for item: StringName in gives:
			items[item] = items.get(item, 0) + gives[item]
	return items


## Whether a tile is tilled soil that is not soaked yet. A crop may stand on it.
func _is_dry_soil(world_pos: Vector2i) -> bool:
	var tile := _state.world.tile_at(world_pos)
	return (
		tile != null
		and tile.terrain == Tile.Terrain.SOIL
		and _state.world.moisture_at(world_pos) < 1.0
	)


func _use_tool(tool_item: Dictionary, object: WorldObject, world_pos: Vector2i) -> Use:
	var is_grass_free := _state.world.is_free_on(world_pos, Tile.Terrain.GRASS)
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
	return (
		Use.FORAGE if object.is_forageable() and not _state.world.is_bare(object) else Use.NOTHING
	)


## Hits an object with the held tool. The hit that finishes it leaves what it leaves (a felled
## tree a stump and a trunk, see TrunkPlacement) and drops its drops around it.
func _hit(object: WorldObject) -> void:
	var power := ItemTypes.tool_power(_state.player.inventory.held_item())
	if not object.is_finished_by(power):
		_state.world.hit_object(object, power)
		return
	var object_type := object.type_data()
	# What it holds (a chest's items, a kiln's load) comes out with it.
	var drops := _items_of_placed(object) if object_type.has("drops") else {}
	if _rolls_seed(object):
		drops[object_type["seed"]] = 1
	if not object_type.has("leaves"):
		_state.world.remove_object(object.pos)
	else:
		var stump := WorldObject.new(object_type["leaves"], object.pos)
		if object_type.get("regrows", false):
			stump.state["tree"] = str(object.type)
		_state.world.replace_object(object, stump)
		TrunkPlacement.lay(_state.world, object, _state.player.tile())
	_state.world.drop_items(object.pos, drops)
	# The finishing hit replaces or removes the object instead of `hit_object`, which emits
	# this for the other hits; the view still shakes and throws particles for it.
	_state.world.object_hit.emit(object)


## Whether felling this tree today also gives its seed. The same tree on the same day always
## rolls the same.
func _rolls_seed(tree: WorldObject) -> bool:
	return PositionHash.rolls(tree.pos, _state.clock.day, tree.type_data().get("seed_chance", 0.0))


## Uses the tile the player faces.
func use_facing_tile() -> Use:
	return use_tile(_state.player.facing_tile())
