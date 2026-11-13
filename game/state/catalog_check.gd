class_name CatalogCheck
extends RefCounted
## Whether the definitions of items and of world objects (ItemTypes, WorldObjectTypes) are
## whole and agree with each other: the fields every definition needs, in range, and every
## reference from one to another (what an item places or plants, what an object drops or leaves
## behind) names something that exists. A problem is "item <id>: <what>" or "object <id>:
## <what>", so the line says where to look. The pictures are checked by AssetCheck, which needs
## the files. Mistakes here are the programmer's, so Main refuses to start on one.


## Whether the shared catalogs are whole; reports every problem, with those found while they
## were put together.
static func report() -> bool:
	var found := ItemTypes.build_problems + WorldObjectTypes.build_problems
	found.append_array(problems(ItemTypes.TYPES, WorldObjectTypes.TYPES))
	for problem in found:
		push_error(problem)
	return found.is_empty()


## The ids of `added_ids` that are in `existing` or earlier in the list: "<kind> <id>: id is used
## twice". `kind` is "item" or "object".
static func reused_ids(kind: String, existing: Dictionary, added_ids: Array) -> Array[String]:
	var found: Array[String] = []
	var taken := existing.keys()
	for id: StringName in added_ids:
		if id in taken:
			found.append("%s %s: id is used twice" % [kind, id])
		taken.append(id)
	return found


## What is wrong with the definitions `items` and `objects` (types by id), as lines of text.
static func problems(items: Dictionary, objects: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var tool_kinds: Array = []
	var placers_of := {}
	for id: StringName in items:
		var item: Dictionary = items[id]
		_check_item(found, id, item, objects)
		if item.has("tool"):
			tool_kinds.append(item["tool"])
		if item.has("places"):
			placers_of[item["places"]] = placers_of.get(item["places"], []) + [id]
	for id: StringName in objects:
		_check_object(found, id, objects[id], items, objects, tool_kinds, placers_of.get(id, []))
	return found


static func _check_item(
	found: Array[String], id: StringName, item: Dictionary, objects: Dictionary
) -> void:
	var at := "item %s: " % id
	for key in ["name", "description"]:
		if not (item.get(key) is String and not item[key].is_empty()):
			found.append(at + "%s must be a text" % key)
	if not (item.get("weight") is float or item.get("weight") is int) or item["weight"] < 0:
		found.append(at + "weight must be a number, 0 or more")
	if not _is_count(item.get("stack_limit")):
		found.append(at + "stack_limit must be a whole number, at least 1")
	if item.has("tool"):
		if not (item.get("level") is int and item["level"] in range(ItemTypes.LEVEL_COUNT)):
			found.append(at + "a tool's level must be from 0 to %d" % (ItemTypes.LEVEL_COUNT - 1))
		if not _is_count(item.get("power")):
			found.append(at + "a tool's power must be a whole number, at least 1")
		if not (item.get("energy_factor") is float and item["energy_factor"] > 0.0):
			found.append(at + "a tool's energy_factor must be a number above 0")
	if item.has("equip_slot"):
		if not item["equip_slot"] in Equipment.SLOTS:
			found.append(at + "equip_slot is not an equipment slot: %s" % item["equip_slot"])
		if item.get("stack_limit") != 1:
			found.append(at + "a wearable has a stack_limit of 1")
	if item.has("plants"):
		_check_object_exists(found, at + "plants", item["plants"], objects)
		var tree: Variant = item.get("plants_state", {}).get("tree")
		if tree != null:
			_check_object_exists(found, at + "plants_state tree", tree, objects)
	if item.has("places"):
		_check_object_exists(found, at + "places", item["places"], objects)


## `placers` are the items that put this object down.
static func _check_object(
	found: Array[String],
	id: StringName,
	object: Dictionary,
	items: Dictionary,
	objects: Dictionary,
	tool_kinds: Array,
	placers: Array
) -> void:
	var at := "object %s: " % id
	var footprint: Variant = object.get("footprint")
	var largest := WorldObjectTypes.MAX_FOOTPRINT
	if not (
		footprint is Vector2i
		and footprint.x in range(1, largest.x + 1)
		and footprint.y in range(1, largest.y + 1)
	):
		found.append(at + "footprint must be from 1x1 to %dx%d tiles" % [largest.x, largest.y])
	if not object.get("blocks_walking") is bool:
		found.append(at + "blocks_walking must be true or false")
	var levels := ItemTypes.LEVEL_COUNT
	if not (object.get("harvest_level") is int and object["harvest_level"] in range(levels)):
		found.append(at + "harvest_level must be from 0 to %d" % (levels - 1))
	if not (object.has("atlas_row") or object.has("interior_sprite") or object.has("sheet")):
		found.append(at + "has no picture: atlas_row, interior_sprite or sheet")
	if object.has("atlas_row"):
		if not (object["atlas_row"] is int and object["atlas_row"] >= 0):
			found.append(at + "atlas_row must be a row number")
		if not _is_count(object.get("variants")):
			found.append(at + "variants must be a whole number, at least 1")
	if object.has("hp"):
		if not _is_count(object["hp"]):
			found.append(at + "hp must be a whole number, at least 1")
		if not object.get("tool") in tool_kinds:
			found.append(at + "tool is the tool of no item: %s" % object.get("tool"))
	if object.has("dig_hits"):
		if not _is_count(object["dig_hits"]):
			found.append(at + "dig_hits must be a whole number, at least 1")
		if not object.has("placed_on"):
			found.append(at + "dig_hits needs placed_on, the ground it is planted on")
	if object.has("seed_chance"):
		var chance: Variant = object["seed_chance"]
		if not (chance is float and chance >= 0.0 and chance <= 1.0):
			found.append(at + "seed_chance must be from 0 to 1")
	if object.has("placed_on"):
		if not (object["placed_on"] is Array and not object["placed_on"].is_empty()):
			found.append(at + "placed_on must be a list of at least one terrain")
	for key in ["seed", "produce"]:
		if object.has(key):
			_check_item_exists(found, at + key, object[key], items)
	for key in ["leaves", "matures_into"]:
		if object.has(key):
			_check_object_exists(found, at + key, object[key], objects)
	var drops: Dictionary = object.get("drops", {})
	for item: StringName in drops:
		_check_item_exists(found, at + "drops", item, items)
		if not _is_count(drops[item]):
			found.append(at + "drops %s needs a whole number, at least 1" % item)
	if not placers.is_empty():
		_check_placement(found, at, object, placers)


## An object an item puts down says where it may be put down, and has the picture for it.
static func _check_placement(
	found: Array[String], at: String, object: Dictionary, placers: Array
) -> void:
	if placers.size() > 1:
		found.append(at + "is placed by more than one item: %s" % ", ".join(placers))
	var placeable_in: Variant = object.get("placeable_in")
	if not placeable_in in WorldObjectTypes.PLACEMENTS:
		found.append(at + "placeable_in must be one of %s" % [WorldObjectTypes.PLACEMENTS])
		return
	if placeable_in != WorldObjectTypes.OUTDOORS and not object.has("interior_sprite"):
		found.append(at + "placeable_in %s needs an interior_sprite" % placeable_in)
	if placeable_in != WorldObjectTypes.INSIDE and not object.has("atlas_row"):
		found.append(at + "placeable_in %s needs an atlas_row" % placeable_in)


static func _is_count(value: Variant) -> bool:
	return value is int and value >= 1


static func _check_item_exists(
	found: Array[String], field: String, item: Variant, items: Dictionary
) -> void:
	if not items.has(item):
		found.append("%s is not an item: %s" % [field, item])


static func _check_object_exists(
	found: Array[String], field: String, object: Variant, objects: Dictionary
) -> void:
	if not objects.has(object):
		found.append("%s is not an object type: %s" % [field, object])
