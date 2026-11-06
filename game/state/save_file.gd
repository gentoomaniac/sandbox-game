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
## 4. Add a test in tests/test_save_upgrade.gd: an old save without the field loads right.
## An upgrade step works on the parsed JSON, before any `from_dict` runs.

const VERSION := 8
## Version 6 had tomatoes, which were not grown here before the 19th century; flax took their
## place, item for item.
const TOMATOES_TO_FLAX := {"tomatoes": "flax", "tomatoes_seeds": "flax_seeds"}
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
	return GameState.from_dict(parsed["game"])


## Version 1 had no inventory, only the number of crops harvested: that is now turnips in the
## starting inventory.
static func _upgrade_from_version_1(game: Dictionary) -> void:
	var inventory := Inventory.with_starting_items()
	# A count beyond what the free slots hold (about 1,500) is dropped.
	inventory.add(ItemTypes.TURNIP, int(game["harvest_count"]))
	game.erase("harvest_count")
	game["player"]["inventory"] = inventory.to_dict()


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
	slots.resize(Inventory.SLOT_COUNT)


## Version 6 had tomatoes: their plants, seeds and fruit become flax, wherever they are (in the
## inventory, on the ground, planted, and in chests outdoors and indoors).
static func _upgrade_from_version_6(game: Dictionary) -> void:
	_tomatoes_to_flax(game["player"]["inventory"]["slots"])
	for ground_item: Dictionary in game["world"]["ground_items"]:
		ground_item["item"] = TOMATOES_TO_FLAX.get(ground_item["item"], ground_item["item"])
	for object in _saved_objects(game):
		object["type"] = TOMATOES_TO_FLAX.get(object["type"], object["type"])
		if object.has("storage"):
			_tomatoes_to_flax(object["storage"])


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


static func _tomatoes_to_flax(slots: Array) -> void:
	for stack: Variant in slots:
		if stack != null:
			stack["item"] = TOMATOES_TO_FLAX.get(stack["item"], stack["item"])


static func _reject(path: String, reason: String) -> void:
	var backup := path + BACKUP_SUFFIX
	push_error(
		"Can't load %s (%s). Moving it to %s and starting a new game." % [path, reason, backup]
	)
	DirAccess.rename_absolute(path, backup)
