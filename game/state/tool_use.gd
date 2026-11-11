class_name ToolUse
extends RefCounted
## What the use action does: `use_at` says what the held item would do on a tile, `use_tile`
## does it and charges the energy. A hoe tills, an axe hits, a scythe mows: the rules of every
## tool are here. Plain logic on the GameState it is given.

## What the use action does on a tile. HARVEST is a ripe crop, FORAGE something a hand picks
## (a bush, a fern), CLEAR a dead crop that a hand pulls up, WATER a watering can wetting tilled
## soil, FILL_CAN the can filled at a well or at fresh water, CAN_EMPTY a can with no water to
## water with (nothing is done), POUR the can emptied a little into a trough, FEED a feed item put
## into a hay rack, COLLECT an empty hand taking the eggs out of a coop's nest, GATE an empty hand
## opening or shutting a pen's gate (see WorldObjectTypes `turns_into`), HIT a tool cut or
## mined at an object, NEEDS_BETTER_TOOL a tool that is too weak for the object, MOW a scythe
## cutting the tall grass and reeds around the target, DIG a shovel in grass (which may find clay),
## PLACE an item that puts an object down (a chest, a station), TAKE_DOWN an axe or pickaxe taking
## down what the player placed inside a house (outdoors it is a HIT),
## NO_ROOM that, with too little room in the inventory for it and what it holds, GIVE_BONE a bone
## given to a dog, which then follows the player, SADDLE the saddle put on a horse and UNSADDLE an
## empty hand taking it off again, PET an empty hand stroking a farm animal or a pet (see Livestock
## `pet`), RIDING anything on horseback (the player gets off first),
## STANDING_ON a tool at a deck the player stands on (see `is_standing_on`), OUT_OF_REACH a tile
## beyond the player's reach (Targeting.REACH) or not on their map: nothing is done there. What a
## harvest, a pick or a final hit gives lies on the ground (see World `drop_items`).
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
	FILL_CAN,
	CAN_EMPTY,
	POUR,
	FEED,
	COLLECT,
	GATE,
	MOW,
	DIG,
	PLACE,
	TAKE_DOWN,
	NO_ROOM,
	GIVE_BONE,
	SADDLE,
	UNSADDLE,
	PET,
	RIDING,
	STANDING_ON,
	OUT_OF_REACH,
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
	Use.POUR: &"water",
	Use.HIT: &"hit",
	Use.MOW: &"mow",
	Use.DIG: &"dig",
}
## The items the use action gives to an animal (a bone to a dog) or puts on one (a saddle on a
## horse).
const ANIMAL_ITEMS := [ItemTypes.BONE, ItemTypes.SADDLE]
## Digging a clay spot gives this much clay, with this chance (rolled once per spot and day).
const CLAY_DIG_YIELD := {ItemTypes.CLAY: 2}
const CLAY_DIG_CHANCE := 0.4
## A bone goes to a dog, and a saddle to a horse, whose feet are this many tiles from the middle of
## the target tile, at the most: a dog is about a tile long, and a horse's feet are its middle.
const ANIMAL_REACH := 1.0

var _state: GameState
## What the use in `_do_use` did, told when it has cost its energy (see `use_tile`).
var _outcome: ActionOutcome


func _init(state: GameState) -> void:
	_state = state


## What `use` would do on a tile with the held item: a hoe tills grass or hoes a dead crop or the
## weeds of fallow soil away, crop seeds plant on soil and tree seeds on grass, a watering can wets
## dry tilled soil, an empty hand harvests a ripe crop, clears a dead one or picks a bush, an axe or
## pickaxe hits what it cuts or mines, a scythe mows if there is tall grass or reeds in its reach, a
## shovel digs in any free grass (the player can't tell a clay spot from the cursor), an item that
## places an object puts it on a free tile, a bone goes to a dog on the tile and a saddle on a
## horse, an empty hand takes the saddle off a horse and, when it has nothing else to do on the
## tile, pets an animal there. Inside, only placing and taking a chest down are possible; on
## horseback, nothing.
func use_at(pos: Vector2i) -> Use:
	if _state.player.horse != null:
		return Use.RIDING
	var held := _state.player.inventory.held_item()
	if held == ItemTypes.NONE:
		return _use_by_hand_inside(pos) if _state.is_inside() else _use_by_hand(pos)
	var item: Dictionary = ItemTypes.TYPES[held]
	if item.has("places") and _can_place_on(pos, item["places"]):
		return Use.PLACE
	if _state.is_inside():
		return _use_inside(item, pos)
	if held in ANIMAL_ITEMS:
		return _use_on_animal(held, pos)
	return _use_outdoors(item, pos)


## Whether the held item does anything anywhere, so it is worth highlighting a target. Nothing
## does on horseback.
func can_use_held_item() -> bool:
	if _state.player.horse != null:
		return false
	var held := _state.player.inventory.held_item()
	if held == ItemTypes.NONE:
		return true
	var item: Dictionary = ItemTypes.TYPES[held]
	return (
		item.has("plants")
		or item.has("places")
		or ACTIVE_TOOLS.has(item.get("tool"))
		or held in ANIMAL_ITEMS
		or YardRules.default_rules().feed_units(held) > 0
	)


## Uses a tile (see `use_at`) and returns what was done, which costs energy (more the
## heavier the load, unless a cheat says otherwise). A use with too little energy left still
## happens; the energy ends at 0 (see `is_out_of_energy`). A tile out of reach, or not on the
## player's map, is refused with nothing changed (OUT_OF_REACH).
func use_tile(target: Vector2i) -> Use:
	if not _is_in_reach(target):
		return Use.OUT_OF_REACH
	var weight_factor := 1.0
	if not _state.cheats.is_weight_off:
		weight_factor = _state.energy_rules.weight_factor(_state.player.carried_weight())
	var drain := 0.0 if _state.cheats.is_drain_off else _state.energy_drain
	var use := _do_use(target)
	if COST_KINDS.has(use):
		var cost := _state.energy_rules.cost_of(COST_KINDS[use]) * weight_factor * drain
		_state.player.energy = maxf(0.0, _state.player.energy - cost)
	if _outcome != null:
		_state.action_done.emit(_outcome)
	return use


func _is_in_reach(target: Vector2i) -> bool:
	return (
		Targeting.is_tile_in_reach(_state.player.tile(), target)
		and _state.current_map.tile_at(target) != null
	)


func _do_use(target: Vector2i) -> Use:
	var use := use_at(target)
	_outcome = null
	match use:
		Use.TILL:
			# A dead crop or the weeds are hoed away: the soil under them is tilled again.
			if _state.world.object_at(target) != null:
				_state.world.remove_object(target)
			_state.world.set_terrain(target, Tile.Terrain.SOIL)
			_done(ActionOutcome.TILL, target)
		Use.PLANT:
			var seeds := _state.player.inventory.held_item()
			var planted := WorldObject.new(ItemTypes.TYPES[seeds]["plants"], target)
			planted.state = ItemTypes.TYPES[seeds].get("plants_state", {}).duplicate()
			if planted.is_crop():
				# Counted from the planting: the crop grows by the hour from now on.
				planted.state["days_growing"] = 0
			_state.world.add_object(planted)
			_state.player.inventory.consume_held()
			_done(ActionOutcome.PLANT, target, planted.type, {seeds: 1})
		Use.HARVEST:
			var crop := _state.world.object_at(target)
			if CropLife.regrows(crop):
				CropLife.regrow(crop)
				_state.world.change_object(crop)
			else:
				_state.world.remove_object(target)
			var harvest := CropLife.harvest_of(crop, _state.harvest_rng)
			_state.world.drop_items(target, harvest)
			_done(ActionOutcome.HARVEST, target, crop.type, harvest)
		Use.CLEAR:
			var dead_crop := _state.world.remove_object(target)
			_done(ActionOutcome.CLEAR, target, dead_crop.type)
		Use.WATER:
			_state.world.set_moisture(target, 1.0)
			_state.player.can_water -= 1
			_done(ActionOutcome.WATER, target)
		Use.POUR:
			var trough := _state.world.object_at(target)
			ObjectStock.add(trough, YardRules.default_rules().pour_units())
			_state.world.change_object(trough)
			_state.player.can_water -= 1
			_done(ActionOutcome.WATER, target, trough.type)
		Use.FEED:
			var rack := _state.world.object_at(target)
			var feed := _state.player.inventory.held_item()
			ObjectStock.add(rack, YardRules.default_rules().feed_units(feed))
			_state.world.change_object(rack)
			_state.player.inventory.consume_held()
			_done(ActionOutcome.FEED, target, rack.type, {feed: 1})
		Use.COLLECT:
			var nest := _state.current_map.object_at(target)
			var eggs := Coop.take_eggs(nest)
			_state.player.inventory.add(ItemTypes.EGG, eggs)
			_done(ActionOutcome.COLLECT, target, nest.type, {ItemTypes.EGG: eggs})
		Use.GATE:
			var gate := _state.world.object_at(target)
			var turned := WorldObject.new(gate.type_data()["turns_into"], gate.pos)
			_state.world.replace_object(gate, turned)
			_done(ActionOutcome.GATE, target, turned.type)
		Use.FILL_CAN:
			_state.player.can_water = EnergyRules.default_rules().can_capacity()
			var well := _state.world.object_at(target)
			_done(ActionOutcome.FILL_CAN, target, &"" if well == null else well.type)
		Use.FORAGE:
			var plant := _state.world.object_at(target)
			if plant.type_data().has("regrow_days"):
				plant.pick()
				_state.world.change_object(plant)
			else:
				_state.world.remove_object(target)
			var picked := plant.picked_drops()
			_state.world.drop_items(target, picked)
			_done(ActionOutcome.FORAGE, target, plant.type, picked)
		Use.MOW:
			var mown := {}
			for plant in _plants_to_mow(target):
				plant.pick()
				_state.world.change_object(plant)
				var cut := plant.picked_drops()
				_state.world.drop_items(plant.pos, cut)
				for item: StringName in cut:
					mown[item] = mown.get(item, 0) + cut[item]
			_done(ActionOutcome.MOW, target, &"", mown)
		Use.DIG:
			_done(ActionOutcome.DIG, target, &"", _dig(target))
		Use.PLACE:
			var held := _state.player.inventory.held_item()
			var placed := WorldObject.new(ItemTypes.TYPES[held]["places"], target)
			_state.current_map.add_object(placed)
			_state.player.inventory.consume_held()
			_state.make_home_if_bedless(placed)
			_done(ActionOutcome.PLACE, target, placed.type, {held: 1})
		Use.TAKE_DOWN:
			var taken_down := _state.current_map.remove_object(target)
			var items := items_of_placed(taken_down)
			# `use_at` already checked that it all fits (or answered NO_ROOM).
			for item: StringName in items:
				_state.player.inventory.add(item, items[item])
			_done(ActionOutcome.TAKE_DOWN, target, taken_down.type, items)
		Use.HIT:
			_hit(_state.world.object_at(target))
		Use.GIVE_BONE:
			_state.livestock.start_following(_dog_at(target), _state.clock.total_minutes())
			_state.player.inventory.consume_held()
			_done(ActionOutcome.GIVE_BONE, target, LivestockRules.DOG, {ItemTypes.BONE: 1})
		Use.SADDLE:
			_horse_at(target).is_saddled = true
			_state.player.inventory.consume_held()
			_done(ActionOutcome.SADDLE, target, LivestockRules.HORSE, {ItemTypes.SADDLE: 1})
		Use.UNSADDLE:
			_horse_at(target).is_saddled = false
			_state.player.inventory.add(ItemTypes.SADDLE, 1)
			_done(ActionOutcome.UNSADDLE, target, LivestockRules.HORSE, {ItemTypes.SADDLE: 1})
		Use.PET:
			var animal := _pettable_at(target)
			var is_asleep := animal.activity == FarmAnimal.Activity.SLEEP
			_state.livestock.pet(animal, _state.clock)
			var kind := ActionOutcome.PET_ASLEEP if is_asleep else ActionOutcome.PET
			_done(kind, target, animal.species)
	return use


func _done(kind: StringName, tile: Vector2i, object := &"", items := {}) -> void:
	_outcome = ActionOutcome.new(kind, _state.current_map, tile, object, items)


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
## else the shovel finds nothing. Returns what it found.
func _dig(target: Vector2i) -> Dictionary:
	if not _state.world.has_clay(target):
		return {}
	_state.world.spend_clay_spot(target)
	if not PositionHash.rolls(target, _state.clock.day, CLAY_DIG_CHANCE):
		return {}
	_state.world.drop_items(target, CLAY_DIG_YIELD)
	return CLAY_DIG_YIELD


## Whether the player can put an object of this type with its top left on a tile: every tile of
## its footprint is free (and of a terrain of its `placed_on`, if it has that), the player's body
## is not on them (they would be stuck in it), and the object goes on this map (its `placeable_in`).
func _can_place_on(pos: Vector2i, placed_type: StringName) -> bool:
	var placed: Dictionary = WorldObjectTypes.TYPES[placed_type]
	var fits_map: bool = (
		placed["placeable_in"]
		in [
			WorldObjectTypes.ANYWHERE,
			WorldObjectTypes.INSIDE if _state.is_inside() else WorldObjectTypes.OUTDOORS,
		]
	)
	var footprint := Rect2i(pos, placed["footprint"])
	if not fits_map or footprint.intersects(PlayerState.body_tiles(_state.player.position)):
		return false
	for x in range(footprint.position.x, footprint.end.x):
		for y in range(footprint.position.y, footprint.end.y):
			if not _is_free_for(Vector2i(x, y), placed):
				return false
	return true


## Whether one tile is free for an object of the type `placed`: where the map lets one tile
## objects be placed, or, for a type with `placed_on` (only outdoors), free and of one of those
## terrains. `placed_on` replaces the rule of buildable ground altogether, so the jetty and the
## boat skip its other rule too: they may lie in front of a door.
func _is_free_for(tile: Vector2i, placed: Dictionary) -> bool:
	if not placed.has("placed_on"):
		return _state.current_map.is_placeable(tile)
	for terrain: Tile.Terrain in placed["placed_on"]:
		if _state.world.is_free_on(tile, terrain):
			return true
	return false


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
	var fits := _state.player.inventory.can_add(items_of_placed(placed))
	return Use.TAKE_DOWN if fits else Use.NO_ROOM


## What the player placed and what it holds (a chest's items, a kiln's load), item id to count:
## what taking it down gives. What has no `drops` (the campfire and the bedroll, which only the
## hammer takes down) gives its item.
func items_of_placed(placed: WorldObject) -> Dictionary:
	var items := items_held_by(placed)
	var drops: Dictionary = placed.type_data().get(
		"drops", {ItemTypes.item_placing(placed.type): 1}
	)
	for item: StringName in drops:
		items[item] = items.get(item, 0) + drops[item]
	return items


## What a placed thing holds, not counting the thing itself: a chest's items, a kiln's load.
func items_held_by(placed: WorldObject) -> Dictionary:
	var items := {} if placed.storage == null else placed.storage.totals()
	var held := StationWork.contents(
		placed, _state.clock.total_minutes(), RecipeRules.default_rules()
	)
	for item: StringName in held:
		items[item] = items.get(item, 0) + held[item]
	return items


## What an item of ANIMAL_ITEMS does on a tile: a bone goes to a dog there, a saddle on a horse
## that has none.
func _use_on_animal(held: StringName, pos: Vector2i) -> Use:
	if held == ItemTypes.BONE:
		return Use.GIVE_BONE if _dog_at(pos) != null else Use.NOTHING
	var horse := _horse_at(pos)
	return Use.SADDLE if horse != null and not horse.is_saddled else Use.NOTHING


## The dog nearest the middle of a tile, within ANIMAL_REACH, or null.
func _dog_at(pos: Vector2i) -> FarmAnimal:
	return _state.livestock.nearest(
		LivestockRules.DOG, Vector2(pos) + Vector2(0.5, 0.5), ANIMAL_REACH
	)


## The horse nearest the middle of a tile, within ANIMAL_REACH, or null.
func _horse_at(pos: Vector2i) -> FarmAnimal:
	return _state.livestock.nearest(
		LivestockRules.HORSE, Vector2(pos) + Vector2(0.5, 0.5), ANIMAL_REACH
	)


## The animal that can be petted nearest to the middle of a tile, within ANIMAL_REACH, or null.
func _pettable_at(pos: Vector2i) -> FarmAnimal:
	return _state.livestock.nearest_pettable(Vector2(pos) + Vector2(0.5, 0.5), ANIMAL_REACH)


## Whether a tile is tilled soil that is not soaked yet. A crop may stand on it.
func _is_dry_soil(world_pos: Vector2i) -> bool:
	var tile := _state.world.tile_at(world_pos)
	return (
		tile != null
		and tile.terrain == Tile.Terrain.SOIL
		and _state.world.moisture_at(world_pos) < 1.0
	)


## What an item that is neither placed nor given to an animal does outdoors: seeds are planted on
## free ground they grow on, a tool does its work (see `_use_tool`).
func _use_outdoors(item: Dictionary, pos: Vector2i) -> Use:
	if (
		item.has("plants")
		and _state.world.is_free_on(pos, item.get("plants_on", Tile.Terrain.SOIL))
	):
		return Use.PLANT
	var object := _state.world.object_at(pos)
	var held := _state.player.inventory.held_item()
	if YardRules.default_rules().feed_units(held) > 0:
		return Use.FEED if _can_take_stock(object, &"feed") else Use.NOTHING
	return _use_tool(item, object, pos)


func _use_tool(tool_item: Dictionary, object: WorldObject, world_pos: Vector2i) -> Use:
	var is_grass_free := _state.world.is_free_on(world_pos, Tile.Terrain.GRASS)
	match tool_item.get("tool"):
		ItemTypes.HOE:
			var is_dead_crop := object != null and object.is_crop() and CropLife.is_dead(object)
			var is_weedy := _state.world.fallow.is_weedy(world_pos)
			return Use.TILL if is_grass_free or is_dead_crop or is_weedy else Use.NOTHING
		ItemTypes.WATERING_CAN:
			return _use_watering_can(object, world_pos)
		ItemTypes.SCYTHE:
			return Use.MOW if not _plants_to_mow(world_pos).is_empty() else Use.NOTHING
		ItemTypes.SHOVEL:
			return Use.DIG if is_grass_free else Use.NOTHING
	return _use_cutting_tool(tool_item, object)


## What the watering can does on a tile: it is filled at a well or at fresh water (unless it is
## full), and waters dry tilled soil while it has water.
func _use_watering_can(object: WorldObject, world_pos: Vector2i) -> Use:
	var has_water := _state.player.can_water > 0
	var is_full := _state.player.can_water >= EnergyRules.default_rules().can_capacity()
	var tile := _state.world.tile_at(world_pos)
	var is_water_source := (
		(object != null and object.type == WorldObjectTypes.DRAW_WELL)
		or (tile != null and tile.is_fresh_water())
	)
	if is_water_source:
		return Use.NOTHING if is_full else Use.FILL_CAN
	if _can_take_stock(object, &"water"):
		return Use.POUR if has_water else Use.CAN_EMPTY
	if not _is_dry_soil(world_pos):
		return Use.NOTHING
	return Use.WATER if has_water else Use.CAN_EMPTY


## Whether the object holds a stock of this kind and has room in it.
func _can_take_stock(object: WorldObject, kind: StringName) -> bool:
	return (
		object != null
		and ObjectStock.is_stocked(object)
		and object.type_data()["stock_kind"] == kind
		and ObjectStock.units(object) < ObjectStock.capacity(object)
	)


## What an axe or a pickaxe does to the object: hit it if it is cut or mined with that tool.
func _use_cutting_tool(tool_item: Dictionary, object: WorldObject) -> Use:
	if object == null or object.type_data().get("tool", ItemTypes.NONE) != tool_item.get("tool"):
		return Use.NOTHING
	if is_standing_on(object):
		return Use.STANDING_ON
	if tool_item["level"] >= object.type_data()["harvest_level"]:
		return Use.HIT
	return Use.NEEDS_BETTER_TOOL


## What an empty hand does on a tile inside a house: it takes the eggs out of a nest that has some
## (a nest holds fewer than a stack, and the empty hand's slot always has room for them: see Coop).
func _use_by_hand_inside(pos: Vector2i) -> Use:
	var nest := _state.current_map.object_at(pos)
	return Use.COLLECT if nest != null and Coop.eggs_in(nest) > 0 else Use.NOTHING


## What an empty hand does on a tile outdoors: it takes the saddle off a horse (the hand's empty
## slot always has room for it), harvests a ripe crop, clears a dead one, picks a bush or opens a
## gate, and with none of that to do pets an animal.
func _use_by_hand(pos: Vector2i) -> Use:
	var horse := _horse_at(pos)
	if horse != null and horse.is_saddled:
		return Use.UNSADDLE
	var use := _use_by_hand_on_object(pos)
	if use == Use.NOTHING and _pettable_at(pos) != null:
		return Use.PET
	return use


func _use_by_hand_on_object(pos: Vector2i) -> Use:
	var object := _state.world.object_at(pos)
	if object == null:
		return Use.NOTHING
	if object.type_data().has("turns_into"):
		return Use.GATE
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
		_done(ActionOutcome.HIT, object.pos, object.type)
		return
	var object_type := object.type_data()
	# What it holds (a chest's items, a kiln's load) comes out with it.
	var drops := items_of_placed(object) if object_type.has("drops") else {}
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
	_done(ActionOutcome.BREAK, object.pos, object.type, drops)


## Whether felling this tree today also gives its seed. The same tree on the same day always
## rolls the same.
func _rolls_seed(tree: WorldObject) -> bool:
	return PositionHash.rolls(tree.pos, _state.clock.day, tree.type_data().get("seed_chance", 0.0))


## Whether the player's body is on a deck (the jetty): taking it away would leave them standing
## in the water, so neither a tool nor the hammer does.
func is_standing_on(object: WorldObject) -> bool:
	var footprint := Rect2i(object.pos, object.type_data()["footprint"])
	return (
		object.type_data().get("deck", false)
		and footprint.intersects(PlayerState.body_tiles(_state.player.position))
	)


## Uses the tile the player faces.
func use_facing_tile() -> Use:
	return use_tile(_state.player.facing_tile())
