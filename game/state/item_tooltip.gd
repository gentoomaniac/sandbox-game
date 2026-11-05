class_name ItemTooltip
extends RefCounted
## The text of an item's tooltip, built from the data: ItemTypes for the name, weight, kind
## and description, data/energy.cfg for food, data/crops.cfg for what seeds grow. One item per
## line, in this order: name, kind, description, what the kind adds, weight.

const PRECISION := 0.01
## Terrains seeds are planted on, as the player calls them.
const TERRAIN_NAMES := {Tile.Terrain.GRASS: "grass", Tile.Terrain.SOIL: "tilled soil"}


## The tooltip of `count` of `item`; empty for no item.
static func text_for(item: StringName, count := 1) -> String:
	if item == ItemTypes.NONE:
		return ""
	var type: Dictionary = ItemTypes.TYPES[item]
	var lines: Array[String] = [type["name"], _kind_line(item, type), type["description"]]
	lines.append_array(_detail_lines(item, type))
	lines.append(weight_text(type["weight"], count))
	return "\n".join(lines)


## "0.3 kg each", and for a stack "0.3 kg each, 5 = 1.5 kg".
static func weight_text(each: float, count: int) -> String:
	var text := "%s kg each" % _plain(each)
	if count > 1:
		text += ", %d = %s kg" % [count, _plain(each * count)]
	return text


## A number without a trailing ".0".
static func _plain(value: float) -> String:
	return String.num(snappedf(value, PRECISION), 2).rstrip("0").rstrip(".")


static func _kind_line(item: StringName, type: Dictionary) -> String:
	if type.has("tool"):
		return "Tool, level %d" % type["level"]
	if type.has("equip_slot"):
		return "Equipment"
	if type.has("plants"):
		return "Seeds"
	if EnergyRules.default_rules().is_food(item):
		return "Food"
	return "Resource"


## What the kind adds to the description.
static func _detail_lines(item: StringName, type: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var energy_rules := EnergyRules.default_rules()
	if energy_rules.is_food(item):
		lines.append("+%s energy" % _plain(energy_rules.food_restore(item)))
	if type.has("plants"):
		var terrain: Tile.Terrain = type.get("plants_on", Tile.Terrain.SOIL)
		lines.append("Grows into: " + _grown_name(type))
		lines.append("Plant on: " + TERRAIN_NAMES[terrain])
	if type.has("equip_slot"):
		lines.append("Worn on: " + str(type["equip_slot"]).replace("_", " ").capitalize())
		# The hook for equipment values: `stats` is {"Warmth": 2, ...}; no item has any yet.
		for stat: String in type.get("stats", {}):
			lines.append("%s %+d" % [stat, type["stats"][stat]])
	return lines


## What seeds grow into: a crop, or the tree a tree seed's sapling will be.
static func _grown_name(seed_type: Dictionary) -> String:
	var plants: StringName = seed_type["plants"]
	if plants == WorldObjectTypes.SAPLING:
		return "%s tree" % str(seed_type["plants_state"]["tree"]).capitalize()
	return CropRules.default_rules().crop(plants)["name"]
