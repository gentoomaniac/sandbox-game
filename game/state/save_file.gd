class_name SaveFile
extends RefCounted
## The save on disk: one JSON file per world, `{"version": VERSION, "game": <GameState.to_dict>}`.
## Saves from OLDEST_VERSION to VERSION (ten upgrade steps) still load, upgraded step by step
## (see `_upgrade_from_version_13` and so on). Older ones are refused.
##
## How to add a save field (or change one):
## 1. Write it in `to_dict` and read it in `from_dict` with `data["name"]`. Never `data.get(...)`
##    with a default: a save without the field is a bug to see, not to hide.
## 2. Raise VERSION by one.
## 3. Add `_upgrade_from_version_<old VERSION>` here, which gives the field to a save of the old
##    version (its default, or computed from what the save has), and call it from `read`.
## 4. Add a test in tests/test_save_upgrade*.gd: an old save without the field loads right.
## 5. Drop the oldest step, the constants and helpers only it uses, and its tests, so that ten
##    steps remain (OLDEST_VERSION moves up with VERSION). That is a commit of its own, titled
##    `Save: drop the upgrade from version <N> (oldest read: <N+1>)`: to rescue a save older
##    than that, find the commit with `git log --grep '^Save: drop'` and check out its parent,
##    which still upgrades it; load and save the game there, then move on to the latest.
## An upgrade step works on the parsed JSON, before any `from_dict` runs.

const VERSION := 23
## The oldest version we still upgrade.
const OLDEST_VERSION := VERSION - 10
## How far around the buildings and the player's objects, and around their tilled fields, the
## coast gives way in a version 17 world (see `_home_tiles`): an old farm keeps its yard.
const UPGRADE_CLEARANCE := 3
const UPGRADE_FIELD_MARGIN := 2
## The ground of the coast, which an old home gives back as grass (see `_clear_new_land`).
const COAST_TERRAINS: Array[Tile.Terrain] = [
	Tile.Terrain.MUD, Tile.Terrain.SALT_MARSH, Tile.Terrain.SEA, Tile.Terrain.WARFT
]
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
	var is_supported: bool = (
		version is float
		and version == int(version)
		and version >= OLDEST_VERSION
		and version <= VERSION
	)
	if not is_supported:
		var reason := "save version %s, this game reads versions %d to %d"
		_reject(path, reason % [version, OLDEST_VERSION, VERSION])
		return null
	if not parsed.has("game"):
		_reject(path, "no game in the save")
		return null
	if version <= 13:
		_upgrade_from_version_13(parsed["game"])
	if version <= 14:
		_upgrade_from_version_14(parsed["game"])
	if version <= 15:
		_upgrade_from_version_15(parsed["game"])
	if version <= 16:
		_upgrade_from_version_16(parsed["game"])
	if version <= 17:
		_upgrade_from_version_17(parsed["game"])
	if version <= 18:
		_upgrade_from_version_18(parsed["game"])
	if version <= 19:
		_upgrade_from_version_19(parsed["game"])
	if version <= 20:
		_upgrade_from_version_20(parsed["game"])
	if version <= 21:
		_upgrade_from_version_21(parsed["game"])
	if version <= 22:
		_upgrade_from_version_22(parsed["game"])
	return GameState.from_dict(parsed["game"])


## Version 13 had no skills: the player starts with none.
static func _upgrade_from_version_13(game: Dictionary) -> void:
	game["player"]["skills"] = {"points": {}, "fading": []}


## Version 14 had no desire paths: all its grass is unworn.
static func _upgrade_from_version_14(game: Dictionary) -> void:
	game["world"]["wear"] = []


## Version 15 had no bones for the dogs: no animal follows the player.
static func _upgrade_from_version_15(game: Dictionary) -> void:
	for animal: Dictionary in game["livestock"]:
		animal["follow_until_minute"] = 0


## Version 16 had no villagers.
static func _upgrade_from_version_16(game: Dictionary) -> void:
	game["npcs"] = []


## Where the player has made a home in a world: around the buildings and around what the player
## put down or changed (UPGRADE_CLEARANCE tiles out), over the tilled fields (their bounding box
## and UPGRADE_FIELD_MARGIN tiles more), under the items on the ground and where the player
## stands.
static func _home_tiles(game: Dictionary) -> Dictionary[Vector2i, bool]:
	var world: Dictionary = game["world"]
	var kept: Dictionary[Vector2i, bool] = {}
	for building: Dictionary in world["buildings"]:
		var type := StringName(building["type"])
		var footprint: Vector2i = BuildingTypes.TYPES[type]["footprint"]
		var origin := SaveCodec.vector_from_json(building["origin"])
		_keep(kept, Rect2i(origin, footprint).grow(UPGRADE_CLEARANCE))
	for edit: Dictionary in world["object_edits"]:
		if edit["object"] != null:
			var object := WorldObject.from_dict(edit["object"])
			var footprint: Vector2i = object.type_data()["footprint"]
			_keep(kept, Rect2i(object.pos, footprint).grow(UPGRADE_CLEARANCE))
	var terrain_edits: Array = world["terrain_edits"]
	var fields := Rect2i()
	for edit: Array in terrain_edits:
		var tile := Rect2i(SaveCodec.vector_from_json(edit), Vector2i.ONE)
		fields = tile if fields.size == Vector2i.ZERO else fields.merge(tile)
	if not terrain_edits.is_empty():
		_keep(kept, fields.grow(UPGRADE_FIELD_MARGIN))
	for ground_item: Dictionary in world["ground_items"]:
		kept[Vector2i(SaveCodec.float_vector_from_json(ground_item["position"]).floor())] = true
	_keep(
		kept, PlayerState.body_tiles(SaveCodec.float_vector_from_json(game["player"]["position"]))
	)
	return kept


## Clears the land the generator makes now off `tiles` of a saved world, as if the player had
## cleared it: the generated objects are taken off, and a ditch or the ground of the coast (the
## foreshore, a Warft) is grass. What the player changed on a tile stays as it is.
static func _clear_new_land(world: Dictionary, generator: WorldGenerator, tiles: Array) -> void:
	var edited_terrain: Dictionary[Vector2i, bool] = {}
	for edit: Array in world["terrain_edits"]:
		edited_terrain[SaveCodec.vector_from_json(edit)] = true
	var edited_objects: Dictionary[Vector2i, bool] = {}
	for edit: Dictionary in world["object_edits"]:
		edited_objects[SaveCodec.vector_from_json(edit["pos"])] = true
	for tile: Vector2i in tiles:
		var terrain := generator.terrain_at(tile)
		var is_new_ground := generator.is_ditch(tile) or terrain in COAST_TERRAINS
		if not edited_terrain.has(tile) and is_new_ground:
			world["terrain_edits"].append(
				SaveCodec.vector_to_json(tile) + [SaveCodec.terrain_to_json(Tile.Terrain.GRASS)]
			)
		if not edited_objects.has(tile) and generator.object_type_at(tile, terrain) != &"":
			world["object_edits"].append({"pos": SaveCodec.vector_to_json(tile), "object": null})


## Version 17 worlds were generated without the coast (task 61): the foreshore with its salt
## marsh, tidal mud, tideways and sea, the sea dyke, Warften and Ewers, and the marsh reaching
## inland from the dyke with its ditches and alders. Where the player has made a home within its
## reach (see `_home_tiles`), it gives way: the ground is
## grass and what the generator puts there now is taken off. Further from home an old world gets
## the coast; a home away from it is left as it was.
static func _upgrade_from_version_17(game: Dictionary) -> void:
	var generator := WorldGenerator.new(int(game["world"]["seed"]))
	var by_the_coast := _home_tiles(game).keys().filter(generator.is_by_the_coast)
	_clear_new_land(game["world"], generator, by_the_coast)


## Version 18 kept no more of who a villager is than their name, sex and look: each is given an
## age, trade and the rest made up from the tables of data/npcs.cfg, the same for the same name.
static func _upgrade_from_version_18(game: Dictionary) -> void:
	var rules := NpcRules.default_rules()
	for npc: Dictionary in game["npcs"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(npc["name"])
		npc.merge(rules.pick_sheet(StringName(npc["sex"]), npc["name"].get_slice(" ", 1), rng))
		npc["id"] = ""


## Version 19 kept no memories of villagers: they remember no conversation.
static func _upgrade_from_version_19(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		npc["memories"] = []
		npc["lines_since_memory"] = 0


## Version 20 made a memory when a chat was closed and counted the lines not in one yet
## (`lines_since_memory`); now the lines beyond the chat's length are made a memory. The lines a
## version 20 memory already holds stay in the chat but are `remembered_lines`: they drop out
## without being summed up again. The lines not in a memory are made one when they drop out.
static func _upgrade_from_version_20(game: Dictionary) -> void:
	for npc: Dictionary in game["npcs"]:
		var unremembered := mini(int(npc["lines_since_memory"]), npc["chat_history"].size())
		npc["remembered_lines"] = npc["chat_history"].size() - unremembered
		npc.erase("lines_since_memory")
		npc["uncompacted_lines"] = []


## Version 21 had no saddles: no horse wears one.
static func _upgrade_from_version_21(game: Dictionary) -> void:
	for animal: Dictionary in game["livestock"]:
		animal["is_saddled"] = false


## Version 22 kept a shorter sheet of who a villager is (task 96 made it longer). One written by
## hand needs nothing: a loaded villager of data/villagers.cfg takes their sheet from it (see Npc
## `from_dict`). A made-up one is made up anew from the tables of data/npcs.cfg, the same for the
## same name, as the old tables gave them English words to say ("Aye") and trades they no longer
## have; one with the surname of a family of the village sheet (Boysen, Hansen, ...) gets another,
## so that they are not taken for kin of that family.
static func _upgrade_from_version_22(game: Dictionary) -> void:
	var villagers := VillagerRules.default_rules()
	var rules := NpcRules.default_rules()
	var village := VillageSheet.default_sheet().text(true)
	for npc: Dictionary in game["npcs"]:
		if villagers.has(npc["id"]):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(npc["name"])
		var surname: String = npc["name"].get_slice(" ", 1)
		if village.contains(surname):
			surname = rules.pick_surname(rng)
			npc["name"] = "%s %s" % [npc["name"].get_slice(" ", 0), surname]
		npc.merge(rules.pick_sheet(StringName(npc["sex"]), surname, rng), true)


static func _keep(kept: Dictionary[Vector2i, bool], area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			kept[Vector2i(x, y)] = true


static func _reject(path: String, reason: String) -> void:
	var backup := path + BACKUP_SUFFIX
	push_error(
		"Can't load %s (%s). Moving it to %s and starting a new game." % [path, reason, backup]
	)
	DirAccess.rename_absolute(path, backup)
