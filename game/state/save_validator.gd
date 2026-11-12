class_name SaveValidator
extends RefCounted
## Checks the game of a save (the `game` of the file, after its upgrades) before anything is
## built from it, so that a damaged save is refused with a message instead of loading half or
## stopping on an assertion. The `from_dict` methods behind it stay strict: they trust what this
## passed.
##
## What it finds is of two kinds:
## - `problems`: the save is damaged (a missing field, a wrong type, a count of -7, a map that
##   is not there). Each says where: "player inventory slot 3: count -7 is not between 1 and 99".
## - `missing`: content the game no longer has (an item, object, tree, recipe or animal that was
##   removed since the save). The save is whole otherwise; `drop_missing` takes those things out
##   of the data, which is the player's choice to make (see LoadResult).
## A save is loadable as it is when both are empty.

enum Kind { TEXT, NUMBER, WHOLE, BOOL, LIST, DICT, VECTOR, POINT }

const KIND_NAMES := {
	Kind.TEXT: "text",
	Kind.NUMBER: "a number",
	Kind.WHOLE: "a whole number",
	Kind.BOOL: "true or false",
	Kind.LIST: "a list",
	Kind.DICT: "a dictionary",
	Kind.VECTOR: "two whole numbers",
	Kind.POINT: "two numbers",
}

var problems: Array[String] = []
## What the game no longer has, each as "what in where".
var missing: Array[String] = []

## What takes one missing thing out of the data, in the order found.
var _removals: Array[Callable] = []
## Whether the building at an origin has an inside, for the map references.
var _has_interior_at: Dictionary[Vector2i, bool] = {}


static func check(game: Variant) -> SaveValidator:
	var validator := SaveValidator.new()
	validator._check_game(game)
	return validator


## Takes what the game no longer has out of the data that was checked: an item leaves its slot,
## an object, animal or pile goes.
func drop_missing() -> void:
	for remove in _removals:
		remove.call()
	_removals.clear()
	missing.clear()


func _check_game(game: Variant) -> void:
	if not game is Dictionary:
		_report("", "the game is %s, not a dictionary" % type_string(typeof(game)))
		return
	var clock: Variant = _field(game, "clock", Kind.DICT, "")
	if clock != null:
		_check_clock(clock)
	var world: Variant = _field(game, "world", Kind.DICT, "")
	if world != null:
		_check_world(world)
	var player: Variant = _field(game, "player", Kind.DICT, "")
	if player != null:
		_check_player(player)
	var livestock: Variant = _field(game, "livestock", Kind.LIST, "")
	if livestock != null:
		_check_livestock(livestock)
	var npcs: Variant = _field(game, "npcs", Kind.LIST, "")
	if npcs != null:
		for index in npcs.size():
			_check_npc(npcs[index], "npcs %d" % index)
	_check_map_reference(game, "current_map")
	_check_map_reference(game, "home_map")


func _check_clock(clock: Dictionary) -> void:
	_field(clock, "day", Kind.WHOLE, "clock")
	var minute: Variant = _field(clock, "minute_of_day", Kind.WHOLE, "clock")
	if minute != null and (minute < 0 or minute >= GameClock.MINUTES_PER_DAY):
		_report("clock", "minute_of_day %d is not in the day" % minute)


# --- The world ---


func _check_world(world: Dictionary) -> void:
	_field(world, "seed", Kind.WHOLE, "world")
	_check_entries(world, "terrain_edits", Kind.TEXT)
	_check_entries(world, "soil_moisture", Kind.NUMBER)
	_field(world, "fallow_nights", Kind.WHOLE, "world")
	_check_entries(world, "fallow_soil", Kind.WHOLE)
	_check_entries(world, "spent_clay_spots", Kind.WHOLE)
	_check_entries(world, "wear", Kind.NUMBER)
	var terrain_edits: Variant = world.get("terrain_edits")
	if terrain_edits is Array:
		for index in terrain_edits.size():
			var edit: Variant = terrain_edits[index]
			if edit is Array and edit.size() == 3 and not Tile.Terrain.has(str(edit[2])):
				_report("world terrain_edits %d" % index, "unknown terrain %s" % edit[2])
	_check_ground_items(world, "world")
	var object_edits: Variant = _field(world, "object_edits", Kind.LIST, "world")
	if object_edits != null:
		for index in object_edits.size():
			_check_object_edit(object_edits[index], "world object_edits %d" % index)
	var buildings: Variant = _field(world, "buildings", Kind.LIST, "world")
	if buildings != null:
		for index in buildings.size():
			_check_building(buildings[index], "world buildings %d" % index)


## A list of `[x, y, value]`, the value of the kind `value_kind`.
func _check_entries(owner: Dictionary, key: String, value_kind: Kind) -> void:
	var entries: Variant = _field(owner, key, Kind.LIST, "world")
	if entries == null:
		return
	for index in entries.size():
		var entry: Variant = entries[index]
		var path := "world %s %d" % [key, index]
		if not (entry is Array and entry.size() == 3):
			_report(path, "should be [x, y, value]")
		elif not (_is_kind(entry.slice(0, 2), Kind.VECTOR) and _is_kind(entry[2], value_kind)):
			_report(path, "should be [x, y, %s]" % KIND_NAMES[value_kind])


## The piles on the ground of a map (the world, or an interior), at `path`.
func _check_ground_items(map: Dictionary, path: String) -> void:
	var piles: Variant = _field(map, "ground_items", Kind.LIST, path)
	if piles != null:
		for index in piles.size():
			_check_ground_item(piles[index], "%s ground_items %d" % [path, index], piles)


func _check_ground_item(pile: Variant, path: String, piles: Array) -> void:
	if not pile is Dictionary:
		_report(path, "should be a dictionary")
		return
	var item: Variant = _field(pile, "item", Kind.TEXT, path)
	var count: Variant = _field(pile, "count", Kind.WHOLE, path)
	_field(pile, "position", Kind.POINT, path)
	if item != null and not ItemTypes.TYPES.has(StringName(item)):
		_add_missing("item %s" % item, path, _removing(piles, pile))
	elif count != null and count < 1:
		_report(path, "count %d is less than 1" % count)


func _check_object_edit(edit: Variant, path: String) -> void:
	if not edit is Dictionary:
		_report(path, "should be a dictionary")
		return
	_field(edit, "pos", Kind.VECTOR, path)
	if not edit.has("object"):
		_report(path, "no object")
	# A removed generated object is saved as null.
	elif edit["object"] != null:
		# Dropped, the tile is left empty: even a generated object that stood there is gone.
		_check_object(edit["object"], path + " object", func() -> void: edit["object"] = null)


func _check_building(building: Variant, path: String) -> void:
	if not building is Dictionary:
		_report(path, "should be a dictionary")
		return
	var type: Variant = _field(building, "type", Kind.TEXT, path)
	var origin: Variant = _field(building, "origin", Kind.VECTOR, path)
	_field(building, "style", Kind.TEXT, path)
	if type != null and not BuildingTypes.TYPES.has(StringName(type)):
		_report(path, "unknown building %s" % type)
	if not building.has("interior"):
		_report(path, "no interior")
		return
	if origin != null:
		_has_interior_at[SaveCodec.vector_from_json(origin)] = building["interior"] != null
	if building["interior"] != null:
		_check_interior(building["interior"], path + " interior")


func _check_interior(interior: Variant, path: String) -> void:
	if not interior is Dictionary:
		_report(path, "should be a dictionary or null")
		return
	_field(interior, "size", Kind.VECTOR, path)
	_field(interior, "exit_tile", Kind.VECTOR, path)
	var tiles: Variant = _field(interior, "tiles", Kind.LIST, path)
	if tiles != null:
		for index in tiles.size():
			var tile: Variant = tiles[index]
			var is_tile: bool = (
				tile is Array
				and tile.size() == 3
				and _is_kind(tile.slice(0, 2), Kind.VECTOR)
				and Tile.Terrain.has(str(tile[2]))
			)
			if not is_tile:
				_report("%s tiles %d" % [path, index], "should be [x, y, terrain]")
	_check_ground_items(interior, path)
	var objects: Variant = _field(interior, "objects", Kind.LIST, path)
	if objects != null:
		for index in objects.size():
			_check_object(
				objects[index], "%s objects %d" % [path, index], _removing(objects, objects[index])
			)


## `drop` takes the object out of the data, if the game no longer has what it is or needs.
func _check_object(object: Variant, path: String, drop: Callable) -> void:
	if not object is Dictionary:
		_report(path, "should be a dictionary")
		return
	var type: Variant = _field(object, "type", Kind.TEXT, path)
	_field(object, "pos", Kind.VECTOR, path)
	var state: Variant = _field(object, "state", Kind.DICT, path)
	if type == null:
		return
	if not WorldObjectTypes.TYPES.has(StringName(type)):
		_add_missing("object %s" % type, path, drop)
		return
	if state != null:
		_check_object_state(state, WorldObjectTypes.TYPES[StringName(type)], path, drop)
	var slot_count := WorldObject.storage_slot_count(StringName(type))
	if slot_count > 0:
		_check_stacks(object, "storage", slot_count, path)


func _check_object_state(
	state: Dictionary, type_data: Dictionary, path: String, drop_object: Callable
) -> void:
	# Every other entry (growth, days_growing, damage, days_until_bears...) is a number.
	for key: Variant in state:
		if key not in ["tree", ProcessStation.RUN] and not _is_kind(state[key], Kind.NUMBER):
			_report(path + " state", "%s should be a number" % key)
	# What a trough or a hay rack holds and the eggs in a nest: whole numbers up to what they hold.
	var capacity: int = type_data.get("stock_capacity", 0)
	if state.has("stock") and _is_kind(state["stock"], Kind.WHOLE):
		_check_between(state["stock"], 0, capacity, path + " state", "stock")
	elif state.has("stock"):
		_report(path + " state", "stock should be a whole number")
	if state.has("eggs") and _is_kind(state["eggs"], Kind.WHOLE):
		var nest_eggs: int = YardRules.default_rules().coop("nest_eggs")
		_check_between(state["eggs"], 0, nest_eggs, path + " state", "eggs")
	elif state.has("eggs"):
		_report(path + " state", "eggs should be a whole number")
	# The tree a stump or sapling comes from.
	if state.has("tree"):
		if not state["tree"] is String:
			_report(path + " state", "tree should be text")
		elif not WorldObjectTypes.TYPES.has(StringName(state["tree"])):
			_add_missing("tree %s" % state["tree"], path, drop_object)
	if state.has(ProcessStation.RUN):
		_check_run(state, path + " state " + ProcessStation.RUN)


## The run of a process station (see ProcessStation): its recipe, start and done minutes, and
## what it makes until that is in the grid.
func _check_run(state: Dictionary, path: String) -> void:
	var run: Variant = state[ProcessStation.RUN]
	if not run is Dictionary:
		_report(path, "should be a dictionary")
		return
	var recipe: Variant = _field(run, "recipe", Kind.TEXT, path)
	_field(run, "start_minute", Kind.WHOLE, path)
	_field(run, "done_minute", Kind.WHOLE, path)
	if recipe != null and not RecipeRules.default_rules().recipe_ids().has(StringName(recipe)):
		_add_missing("recipe %s" % recipe, path, func() -> void: state.erase(ProcessStation.RUN))
	if not run.has("products"):
		return
	var products: Variant = run["products"]
	if not products is Dictionary:
		_report(path, "products should be a dictionary")
		return
	for item: Variant in products:
		if not ItemTypes.TYPES.has(StringName(str(item))):
			_add_missing("item %s" % item, path, func() -> void: products.erase(item))
		elif not (_is_kind(products[item], Kind.WHOLE) and products[item] >= 1):
			_report(path, "products %s should be a whole number, at least 1" % item)


# --- Item slots ---


## The slots of `owner[key]`: `slot_count` of them, each empty (null) or a stack of an item the
## game has, of a count from 1 to the item's stack limit.
func _check_stacks(owner: Dictionary, key: String, slot_count: int, path: String) -> void:
	var slots: Variant = _field(owner, key, Kind.LIST, path)
	if slots == null:
		return
	if slots.size() != slot_count:
		_report(path, "%s has %d slots, not %d" % [key, slots.size(), slot_count])
		return
	for slot in slot_count:
		var stack: Variant = slots[slot]
		var slot_path := "%s slot %d" % [path, slot]
		if stack == null:
			continue
		if not stack is Dictionary:
			_report(slot_path, "should be a stack or null")
			continue
		var item: Variant = _field(stack, "item", Kind.TEXT, slot_path)
		var count: Variant = _field(stack, "count", Kind.WHOLE, slot_path)
		if item == null or count == null:
			continue
		if not ItemTypes.TYPES.has(StringName(item)):
			_add_missing("item %s" % item, slot_path, func() -> void: slots[slot] = null)
			continue
		var limit: int = ItemTypes.TYPES[StringName(item)]["stack_limit"]
		if count < 1 or count > limit:
			_report(slot_path, "count %d is not between 1 and %d" % [count, limit])


# --- The player, animals and villagers ---


func _check_player(player: Dictionary) -> void:
	_field(player, "position", Kind.POINT, "player")
	_field(player, "facing", Kind.VECTOR, "player")
	_field(player, "home_bed", Kind.VECTOR, "player")
	_field(player, "energy", Kind.NUMBER, "player")
	_field(player, "health", Kind.NUMBER, "player")
	_field(player, "is_debuffed", Kind.BOOL, "player")
	_field(player, "is_lantern_lit", Kind.BOOL, "player")
	var can_water: Variant = _field(player, "can_water", Kind.WHOLE, "player")
	_check_between(can_water, 0, EnergyRules.default_rules().can_capacity(), "player", "can_water")
	var appearance: Variant = _field(player, "appearance", Kind.DICT, "player")
	if appearance != null:
		_check_appearance(appearance, "player appearance")
	var inventory: Variant = _field(player, "inventory", Kind.DICT, "player")
	if inventory != null:
		_check_inventory(inventory)
	var equipment: Variant = _field(player, "equipment", Kind.DICT, "player")
	if equipment != null:
		_check_equipment(equipment)
	var skills: Variant = _field(player, "skills", Kind.DICT, "player")
	if skills != null:
		_check_skills(skills)
	var attributes: Variant = _field(player, "attributes", Kind.DICT, "player")
	if attributes != null:
		_check_attributes(attributes)


func _check_inventory(inventory: Dictionary) -> void:
	var path := "player inventory"
	_check_stacks(inventory, "slots", Inventory.SLOT_COUNT, path)
	var selected: Variant = _field(inventory, "selected_slot", Kind.WHOLE, path)
	if selected != null and (selected < 0 or selected >= Inventory.HOTBAR_SIZE):
		_report(
			path,
			(
				"selected_slot %d is not a hotbar slot (0 to %d)"
				% [selected, Inventory.HOTBAR_SIZE - 1]
			)
		)


func _check_equipment(equipment: Dictionary) -> void:
	for slot: Variant in equipment:
		var path := "player equipment %s" % slot
		var item: Variant = equipment[slot]
		if not item is String:
			_report(path, "should be an item id")
		elif not Equipment.SLOTS.has(StringName(slot)):
			_report(path, "not an equipment slot")
		elif not ItemTypes.TYPES.has(StringName(item)):
			_add_missing("item %s" % item, path, func() -> void: equipment.erase(slot))
		elif not Equipment.fits(StringName(slot), StringName(item)):
			_report(path, "%s can't be worn there" % item)


func _check_skills(skills: Dictionary) -> void:
	var points: Variant = _field(skills, "points", Kind.DICT, "player skills")
	if points != null:
		for skill: Variant in points:
			if not _is_kind(points[skill], Kind.NUMBER):
				_report("player skills points %s" % skill, "should be a number")
	var fading: Variant = _field(skills, "fading", Kind.LIST, "player skills")
	if fading != null and not fading.all(func(skill: Variant) -> bool: return skill is String):
		_report("player skills fading", "should be a list of text")


func _check_attributes(attributes: Dictionary) -> void:
	var levels: Variant = _field(attributes, "levels", Kind.DICT, "player attributes")
	if levels == null:
		return
	var rules := AttributeRules.default_rules()
	for attribute in rules.attribute_ids():
		var level: Variant = _field(levels, str(attribute), Kind.WHOLE, "player attributes levels")
		_check_between(
			level, rules.min_level(), rules.max_level(), "player attributes levels", str(attribute)
		)


func _check_appearance(appearance: Dictionary, path: String) -> void:
	var layers: Variant = _field(appearance, "layers", Kind.LIST, path)
	if layers == null:
		return
	for index in layers.size():
		var layer: Variant = layers[index]
		var is_layer: bool = (
			layer is Dictionary and layer.get("slot") is String and layer.get("variant") is String
		)
		if not is_layer:
			_report("%s layers %d" % [path, index], "should have a slot and a variant")


func _check_livestock(animals: Array) -> void:
	var rules := LivestockRules.default_rules()
	var max_friendship := float(rules.friendship("max"))
	for index in animals.size():
		var animal: Variant = animals[index]
		var path := "livestock %d" % index
		if not animal is Dictionary:
			_report(path, "should be a dictionary")
			continue
		var species: Variant = _field(animal, "species", Kind.TEXT, path)
		var look: Variant = _field(animal, "look", Kind.TEXT, path)
		var tint: Variant = _field(animal, "tint", Kind.TEXT, path)
		_field(animal, "position", Kind.POINT, path)
		_field(animal, "follow_until_minute", Kind.WHOLE, path)
		_field(animal, "is_saddled", Kind.BOOL, path)
		for need in ["hunger", "thirst"]:
			_check_between(_field(animal, need, Kind.NUMBER, path), 0.0, 1.0, path, need)
		_check_between(
			_field(animal, "friendship", Kind.WHOLE, path), 0.0, max_friendship, path, "friendship"
		)
		_field(animal, "last_petted_day", Kind.WHOLE, path)
		_field(animal, "last_petted_asleep_day", Kind.WHOLE, path)
		if tint != null and not Color.html_is_valid(tint):
			_report(path, "tint %s is not a colour" % tint)
		if species == null or look == null:
			continue
		if not LivestockRules.SPECIES.has(StringName(species)):
			_add_missing("animal %s" % species, path, _removing(animals, animal))
		elif not rules.looks(StringName(species)).has(look):
			_add_missing("look %s of the %s" % [look, species], path, _removing(animals, animal))


func _check_npc(npc: Variant, path: String) -> void:
	if not npc is Dictionary:
		_report(path, "should be a dictionary")
		return
	var sex: Variant = _field(npc, "sex", Kind.TEXT, path)
	if sex != null and not NpcRules.SEXES.has(StringName(sex)):
		_report(path, "unknown sex %s" % sex)
	_field(npc, "name", Kind.TEXT, path)
	var id: Variant = _field(npc, "id", Kind.TEXT, path)
	# A villager of data/villagers.cfg takes their sheet from the file (see Npc `from_dict`).
	if id == null or not VillagerRules.default_rules().has(id):
		for key in ["trade", "personality", "background", "home", "speech"]:
			_field(npc, key, Kind.TEXT, path)
		for key in ["likes", "wants", "day", "habits", "avoids", "secrets"]:
			_field(npc, key, Kind.TEXT, path)
		_field(npc, "age", Kind.WHOLE, path)
		_field(npc, "people", Kind.DICT, path)
		_check_texts(npc, "samples", path)
	_field(npc, "remembered_lines", Kind.WHOLE, path)
	for key in ["position", "anchor"]:
		_field(npc, key, Kind.POINT, path)
	_check_texts(npc, "memories", path)
	var appearance: Variant = _field(npc, "appearance", Kind.DICT, path)
	if appearance != null:
		_check_appearance(appearance, path + " appearance")
	for key in ["chat_history", "uncompacted_lines"]:
		var lines: Variant = _field(npc, key, Kind.LIST, path)
		if lines != null:
			for index in lines.size():
				_check_chat_line(lines[index], "%s %s %d" % [path, key, index])


func _check_texts(owner: Dictionary, key: String, path: String) -> void:
	var texts: Variant = _field(owner, key, Kind.LIST, path)
	if texts != null and not texts.all(func(text: Variant) -> bool: return text is String):
		_report("%s %s" % [path, key], "should be a list of text")


func _check_chat_line(line: Variant, path: String) -> void:
	if not line is Dictionary:
		_report(path, "should be a dictionary")
		return
	_field(line, "day", Kind.WHOLE, path)
	_field(line, "minute", Kind.WHOLE, path)
	_field(line, "from_player", Kind.BOOL, path)
	_field(line, "text", Kind.TEXT, path)


## The map of `game[key]`: the world, or the inside of a building of the world that has one.
func _check_map_reference(game: Dictionary, key: String) -> void:
	var map_reference: Variant = _field(game, key, Kind.DICT, "")
	if map_reference == null:
		return
	var kind: Variant = _field(map_reference, "kind", Kind.TEXT, key)
	if kind == "interior":
		var building: Variant = _field(map_reference, "building", Kind.VECTOR, key)
		if (
			building != null
			and not _has_interior_at.get(SaveCodec.vector_from_json(building), false)
		):
			_report(key, "no building with an inside at %s" % SaveCodec.vector_from_json(building))
	elif kind != null and kind != "world":
		_report(key, "unknown kind of map %s" % kind)


# --- What the checks share ---


## Reports a number that is there (`value` is not null) and outside `low` to `high`.
func _check_between(value: Variant, low: Variant, high: Variant, path: String, key: String) -> void:
	if value != null and (value < low or value > high):
		_report(path, "%s %s is not between %s and %s" % [key, value, low, high])


## The value of `owner[key]` if it is there and of `kind`; else null, with a problem reported
## at `path`.
func _field(owner: Dictionary, key: String, kind: Kind, path: String) -> Variant:
	if not owner.has(key):
		_report(path, "no %s" % key)
		return null
	if not _is_kind(owner[key], kind):
		_report(_join(path, key), "should be %s" % KIND_NAMES[kind])
		return null
	return owner[key]


static func _is_kind(value: Variant, kind: Kind) -> bool:
	match kind:
		Kind.TEXT:
			return value is String
		Kind.NUMBER:
			return value is float or value is int
		Kind.WHOLE:
			return value is int or (value is float and value == floorf(value))
		Kind.BOOL:
			return value is bool
		Kind.LIST:
			return value is Array
		Kind.DICT:
			return value is Dictionary
		Kind.VECTOR:
			return (
				value is Array
				and value.size() == 2
				and value.all(func(part: Variant) -> bool: return _is_kind(part, Kind.WHOLE))
			)
		Kind.POINT:
			return (
				value is Array
				and value.size() == 2
				and value.all(func(part: Variant) -> bool: return _is_kind(part, Kind.NUMBER))
			)
	return false


static func _join(path: String, key: String) -> String:
	return key if path == "" else "%s %s" % [path, key]


func _report(path: String, message: String) -> void:
	problems.append(message if path == "" else "%s: %s" % [path, message])


func _add_missing(what: String, path: String, remove: Callable) -> void:
	missing.append("%s in %s" % [what, path])
	_removals.append(remove)


## Takes `entry` out of `list` (the very one, not an equal one).
static func _removing(list: Array, entry: Variant) -> Callable:
	return func() -> void:
		list.assign(list.filter(func(other: Variant) -> bool: return not is_same(other, entry)))
