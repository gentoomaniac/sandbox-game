class_name SaveFile
extends RefCounted
## The save on disk: one JSON file per world, `{"version": VERSION, "game": <GameState.to_dict>}`.
## Older saves still load, upgraded step by step (see `_upgrade_from_version_1` and so on).
##
## How to add a save field (or change one):
## 1. Write it in `to_dict` and read it in `from_dict` with `data["name"]`. Never `data.get(...)`
##    with a default: a save without the field is a bug to see, not to hide.
## 2. Raise VERSION by one.
## 3. Add `_upgrade_from_version_<old VERSION>` here, which gives the field to a save of the old
##    version (its default, or computed from what the save has), and call it from `read`.
## 4. Add a test in tests/test_save_upgrade*.gd: an old save without the field loads right.
## An upgrade step works on the parsed JSON, before any `from_dict` runs.

const VERSION := 12
## Version 6 had tomatoes, which were not grown here before the 19th century; flax took their
## place, item for item.
const TOMATOES_TO_FLAX := {"tomatoes": "flax", "tomatoes_seeds": "flax_seeds"}
## Version 8 dressed the player in a tunic and trousers; the clothes of the period took their
## place, item for item.
const TUNIC_AND_TROUSERS_TO_PERIOD := {"tunic": "waistcoat", "trousers": "breeches"}
## Version 10 had a hotbar of 10 slots, with the backpack's 20 slots after it.
const VERSION_10_HOTBAR_SIZE := 10
const VERSION_10_SLOT_COUNT := 30
## How far around the buildings and the player's objects, and around their tilled fields, the
## worked land gives way in a version 9 world (see `_upgrade_from_version_9`): an old farm keeps
## its yard.
const UPGRADE_CLEARANCE := 3
const UPGRADE_FIELD_MARGIN := 2
## How far apart the piles lie that a version 10 inventory leaves on the ground, in tiles.
const UPGRADE_PILE_SPACING := 0.3
const DEFAULT_PATH := "user://saves/world.json"
## What a save we can't use is renamed to, so it is never overwritten silently.
const BACKUP_SUFFIX := ".bak"


## Writes the game to `path`. Returns whether it worked.
static func write(state: GameState, path: String = DEFAULT_PATH) -> bool:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		push_error("Can't create the save folder: %s" % error_string(error))
		return false
	# Written beside the save and renamed over it, so a crash never leaves half a save.
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s: %s" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({"version": VERSION, "game": state.to_dict()}, "\t"))
	file.close()
	error = DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		push_error("Can't replace %s: %s" % [path, error_string(error)])
		return false
	return true


## The saved game, or null if there is no save. A save that can't be read (broken, or from
## another version) is reported, moved aside to `<path>.bak` and also gives null: the caller
## starts a new game.
static func read(path: String = DEFAULT_PATH) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	# Not parse_string: it prints an engine error of its own for broken text.
	var json := JSON.new()
	var parsed: Variant = (
		json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	)
	if not parsed is Dictionary:
		_reject(path, "not a save file")
		return null
	# JSON parsing gives numbers as floats.
	var version: Variant = parsed.get("version")
	if not (version is float and version == int(version) and version >= 1 and version <= VERSION):
		_reject(path, "save version %s, this game reads versions 1 to %d" % [version, VERSION])
		return null
	if not parsed.has("game"):
		_reject(path, "no game in the save")
		return null
	if version == 1:
		_upgrade_from_version_1(parsed["game"])
	if version <= 2:
		_upgrade_from_version_2(parsed["game"])
	if version <= 3:
		_upgrade_from_version_3(parsed["game"])
	if version <= 4:
		_upgrade_from_version_4(parsed["game"])
	if version <= 5:
		_upgrade_from_version_5(parsed["game"])
	if version <= 6:
		_upgrade_from_version_6(parsed["game"])
	if version <= 7:
		_upgrade_from_version_7(parsed["game"])
	if version <= 8:
		_upgrade_from_version_8(parsed["game"])
	if version <= 9:
		_upgrade_from_version_9(parsed["game"])
	if version <= 10:
		_upgrade_from_version_10(parsed["game"])
	if version <= 11:
		_upgrade_from_version_11(parsed["game"])
	return GameState.from_dict(parsed["game"])


## Version 1 had no inventory, only the number of crops harvested: that is now turnips with the
## starting tools as the game has them today, in the 20 slots of version 5 (the later steps
## widen them).
static func _upgrade_from_version_1(game: Dictionary) -> void:
	var inventory := ItemSlots.new(20)
	assert(Inventory.STARTING_ITEMS.size() <= 20, "The starting items outgrew version 5's slots")
	for slot in Inventory.STARTING_ITEMS.size():
		var item_and_count: Array = Inventory.STARTING_ITEMS[slot]
		inventory.slots[slot] = {"item": item_and_count[0], "count": item_and_count[1]}
	# A count beyond what the free slots hold is dropped.
	inventory.add(ItemTypes.TURNIP, int(game["harvest_count"]))
	game.erase("harvest_count")
	game["player"]["inventory"] = {"slots": inventory.slots_to_data(), "selected_slot": 0}


## Version 2 had no items on the ground, and called logs `wood`.
static func _upgrade_from_version_2(game: Dictionary) -> void:
	game["world"]["ground_items"] = []
	for stack: Variant in game["player"]["inventory"]["slots"]:
		if stack != null and stack["item"] == "wood":
			stack["item"] = "logs"


## Version 3 had one kind of sapling item, which planted an oak: now the acorn does.
static func _upgrade_from_version_3(game: Dictionary) -> void:
	for stack: Variant in game["player"]["inventory"]["slots"]:
		if stack != null and stack["item"] == "sapling":
			stack["item"] = "acorn"
	for ground_item: Dictionary in game["world"]["ground_items"]:
		if ground_item["item"] == "sapling":
			ground_item["item"] = "acorn"


## Version 4 had one building, the small house: now the Kate.
static func _upgrade_from_version_4(game: Dictionary) -> void:
	for building: Dictionary in game["world"]["buildings"]:
		if building["type"] == "small_house":
			building["type"] = "kate"


## Version 5 had 20 inventory slots, the first ten the hotbar: the backpack now has ten more,
## after them, so every item keeps its slot.
static func _upgrade_from_version_5(game: Dictionary) -> void:
	var slots: Array = game["player"]["inventory"]["slots"]
	slots.resize(VERSION_10_SLOT_COUNT)


## Version 6 had tomatoes: their plants, seeds and fruit become flax, wherever they are (in the
## inventory, on the ground, planted, and in chests outdoors and indoors).
static func _upgrade_from_version_6(game: Dictionary) -> void:
	_rename_items(game["player"]["inventory"]["slots"], TOMATOES_TO_FLAX)
	for ground_item: Dictionary in game["world"]["ground_items"]:
		ground_item["item"] = TOMATOES_TO_FLAX.get(ground_item["item"], ground_item["item"])
	for object in _saved_objects(game):
		object["type"] = TOMATOES_TO_FLAX.get(object["type"], object["type"])
		if object.has("storage"):
			_rename_items(object["storage"], TOMATOES_TO_FLAX)


## Version 7 saves may lack fields that were added to version 7 without a new version: soil
## moisture, spent clay spots, the outfit, energy, health and the debuff, and the empty store of
## a chest made before chests stored anything. A field the save has is kept. Crops counted days
## in `days_grown`, one growth stage each; they now keep `growth`.
static func _upgrade_from_version_7(game: Dictionary) -> void:
	var world: Dictionary = game["world"]
	world.get_or_add("soil_moisture", [])
	world.get_or_add("spent_clay_spots", [])
	var player: Dictionary = game["player"]
	player.get_or_add("equipment", Equipment.with_starting_outfit().to_dict())
	player.get_or_add("energy", PlayerState.MAX_ENERGY)
	player.get_or_add("health", PlayerState.MAX_HEALTH)
	player.get_or_add("is_debuffed", false)
	for object in _saved_objects(game):
		var type_data: Dictionary = WorldObjectTypes.TYPES[StringName(object["type"])]
		if type_data.has("storage_slots"):
			object.get_or_add("storage", ItemSlots.new(type_data["storage_slots"]).slots_to_data())
		if type_data.has("growth_stages") and object["state"].has("days_grown"):
			var state: Dictionary = object["state"]
			state["growth"] = float(state["days_grown"]) * type_data["growth_per_stage"]
			state.erase("days_grown")


## Version 8 had a tunic and trousers: they become the waistcoat and breeches wherever they are
## (worn, in the inventory, on the ground and in chests outdoors and indoors). Feet were always
## bare, as there was nothing to wear on them: they get the clogs of the starting outfit.
static func _upgrade_from_version_8(game: Dictionary) -> void:
	var player: Dictionary = game["player"]
	_rename_items(player["inventory"]["slots"], TUNIC_AND_TROUSERS_TO_PERIOD)
	var equipment: Dictionary = player["equipment"]
	for slot: String in equipment:
		equipment[slot] = TUNIC_AND_TROUSERS_TO_PERIOD.get(equipment[slot], equipment[slot])
	equipment.get_or_add(str(Equipment.FEET), str(ItemTypes.CLOGS))
	for ground_item: Dictionary in game["world"]["ground_items"]:
		ground_item["item"] = TUNIC_AND_TROUSERS_TO_PERIOD.get(
			ground_item["item"], ground_item["item"]
		)
	for object in _saved_objects(game):
		if object.has("storage"):
			_rename_items(object["storage"], TUNIC_AND_TROUSERS_TO_PERIOD)


## Version 9 worlds were generated without the worked land (Knicks, walls, fences, dykes,
## ditches, willows), which the same seed now has. Where the player has made a home it gives way,
## as if the player had cleared it: around the buildings and around what the player put down or
## changed (UPGRADE_CLEARANCE tiles out), over the tilled fields (their bounding box and
## UPGRADE_FIELD_MARGIN tiles more), under the items on the ground and where the player stands,
## the generated objects are taken off and a ditch is grass. So nothing new stands in or by a
## house, across the yard, the camp or the fields, or shuts the player in.
static func _upgrade_from_version_9(game: Dictionary) -> void:
	var world: Dictionary = game["world"]
	var kept: Dictionary[Vector2i, bool] = {}
	for building: Dictionary in world["buildings"]:
		var type := StringName(building["type"])
		var footprint: Vector2i = BuildingTypes.TYPES[type]["footprint"]
		var origin := SaveCodec.vector_from_json(building["origin"])
		_keep(kept, Rect2i(origin, footprint).grow(UPGRADE_CLEARANCE))
	var edited_objects: Dictionary[Vector2i, bool] = {}
	for edit: Dictionary in world["object_edits"]:
		edited_objects[SaveCodec.vector_from_json(edit["pos"])] = true
		if edit["object"] != null:
			var object := WorldObject.from_dict(edit["object"])
			var footprint: Vector2i = object.type_data()["footprint"]
			_keep(kept, Rect2i(object.pos, footprint).grow(UPGRADE_CLEARANCE))
	var edited_terrain: Dictionary[Vector2i, bool] = {}
	var fields := Rect2i()
	for edit: Array in world["terrain_edits"]:
		var tile := Rect2i(SaveCodec.vector_from_json(edit), Vector2i.ONE)
		fields = tile if edited_terrain.is_empty() else fields.merge(tile)
		edited_terrain[tile.position] = true
	if not edited_terrain.is_empty():
		_keep(kept, fields.grow(UPGRADE_FIELD_MARGIN))
	for ground_item: Dictionary in world["ground_items"]:
		kept[Vector2i(SaveCodec.float_vector_from_json(ground_item["position"]).floor())] = true
	_keep(
		kept, PlayerState.body_tiles(SaveCodec.float_vector_from_json(game["player"]["position"]))
	)
	var generator := WorldGenerator.new(int(world["seed"]))
	for tile in kept:
		if not edited_terrain.has(tile) and generator.is_ditch(tile):
			world["terrain_edits"].append(
				SaveCodec.vector_to_json(tile) + [SaveCodec.terrain_to_json(Tile.Terrain.GRASS)]
			)
		var generated := generator.object_type_at(tile, generator.terrain_at(tile))
		if not edited_objects.has(tile) and generated != &"":
			world["object_edits"].append({"pos": SaveCodec.vector_to_json(tile), "object": null})


## Version 10 had a hotbar of ten slots; it has Inventory.HOTBAR_SIZE now. What lay in the
## slots it lost goes to the first free slots of the backpack (onto stacks of the same item
## first), and what has no room there onto the ground at the player's feet.
## This step builds today's layout from Inventory; when the layout changes again, give the new
## step its own constants and freeze these at version 11's (8 hotbar slots, 28 in all).
static func _upgrade_from_version_10(game: Dictionary) -> void:
	var player: Dictionary = game["player"]
	var saved_inventory: Dictionary = player["inventory"]
	var old_slots: Array = saved_inventory["slots"]
	var inventory := Inventory.new()
	inventory.load_slots(
		(
			old_slots.slice(0, Inventory.HOTBAR_SIZE)
			+ old_slots.slice(VERSION_10_HOTBAR_SIZE, VERSION_10_SLOT_COUNT)
		)
	)
	var backpack_slots := range(Inventory.HOTBAR_SIZE, Inventory.SLOT_COUNT)
	var lost_slots := old_slots.slice(Inventory.HOTBAR_SIZE, VERSION_10_HOTBAR_SIZE)
	var feet := SaveCodec.float_vector_from_json(player["position"])
	var piles := 0
	for stack: Variant in lost_slots:
		if stack == null:
			continue
		var item := StringName(stack["item"])
		var left := inventory.add(item, int(stack["count"]), backpack_slots)
		if left > 0:
			# Piles on one spot would hide each other.
			var position := feet + Vector2.RIGHT * UPGRADE_PILE_SPACING * piles
			game["world"]["ground_items"].append(GroundItem.new(item, left, position).to_dict())
			piles += 1
	saved_inventory["slots"] = inventory.slots_to_data()
	if int(saved_inventory["selected_slot"]) >= Inventory.HOTBAR_SIZE:
		saved_inventory["selected_slot"] = 0


## Version 11 rooms had one floor; the maps now lay brick in the living rooms and clay in the
## work rooms (the byre, the barn, the shack). A saved room takes the floor of its building's
## map of today, tile by tile; its walls and furniture stay as they were.
static func _upgrade_from_version_11(game: Dictionary) -> void:
	for building: Dictionary in game["world"]["buildings"]:
		if building["interior"] == null:
			continue
		var map_path: String = BuildingTypes.TYPES[StringName(building["type"])]["interior_map"]
		var today := InteriorLoader.load_interior(map_path)
		for tile: Array in building["interior"]["tiles"]:
			var today_tile := today.tile_at(SaveCodec.vector_from_json(tile))
			if tile[2] == "FLOOR" and today_tile != null and today_tile.is_floor():
				tile[2] = SaveCodec.terrain_to_json(today_tile.terrain)


static func _keep(kept: Dictionary[Vector2i, bool], area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			kept[Vector2i(x, y)] = true


## The saved world objects outside the loaded chunks: those the player changed in the world and
## those inside buildings.
static func _saved_objects(game: Dictionary) -> Array:
	var objects: Array = []
	for edit: Dictionary in game["world"]["object_edits"]:
		if edit["object"] != null:
			objects.append(edit["object"])
	for building: Dictionary in game["world"]["buildings"]:
		if building["interior"] != null:
			objects.append_array(building["interior"]["objects"])
	return objects


## Renames the items of saved slots by `renames` (old id to new id).
static func _rename_items(slots: Array, renames: Dictionary) -> void:
	for stack: Variant in slots:
		if stack != null:
			stack["item"] = renames.get(stack["item"], stack["item"])


static func _reject(path: String, reason: String) -> void:
	var backup := path + BACKUP_SUFFIX
	push_error(
		"Can't load %s (%s). Moving it to %s and starting a new game." % [path, reason, backup]
	)
	DirAccess.rename_absolute(path, backup)
