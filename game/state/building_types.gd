class_name BuildingTypes
extends RefCounted
## The kinds of building and their styles, as data from data/buildings.cfg (see there and
## BuildingRules). `TYPES` holds each building's own look by its type name, `of` any of its
## styles. Each entry has the keys of the file, and also:
## - costs: the materials placing it takes, item id to count (only those that are not 0).

const SHACK := &"shack"
const FISHER_HUT := &"fisher_hut"
const KATE := &"kate"
const LONGHOUSE := &"longhouse"
const HALL_HOUSE := &"hall_house"
const BARN := &"barn"
const CHURCH := &"church"
const BELL_FRAME := &"bell_frame"
const CHICKEN_COOP := &"chicken_coop"

## The material of each `cost_<material>` key of the file.
const COST_ITEMS := {
	"cost_logs": ItemTypes.LOGS,
	"cost_stone": ItemTypes.STONE,
	"cost_clay": ItemTypes.CLAY,
	"cost_reeds": ItemTypes.REEDS,
}

# The names are those of constants, but the types are only known once the file is read.
## {type: {style id: entry}}, with the building's own look as style &"".
static var STYLES := _from_rules()  # gdlint: ignore=class-variable-name
## {type: entry} of each building's own look. It goes once every caller asks `of` for the style.
static var TYPES := _own_looks()  # gdlint: ignore=class-variable-name


## The building ids, in the order of the file.
static func ids() -> Array[StringName]:
	return BuildingRules.default_rules().building_ids()


## A building's styles, in the order of the file: its own first, as &"".
static func styles(building_type: StringName) -> Array[StringName]:
	var style_ids: Array[StringName] = []
	style_ids.assign(STYLES[building_type].keys())
	return style_ids


## The entry of one style of a building. A style the file no longer has (a save of a building
## placed before it was taken out) gives the building's own look.
static func of(building_type: StringName, style: StringName) -> Dictionary:
	return STYLES[building_type].get(style, TYPES[building_type])


static func _from_rules() -> Dictionary:
	var rules := BuildingRules.default_rules()
	var types := {}
	for building_id in rules.building_ids():
		types[building_id] = {}
		for style_id in rules.style_ids(building_id):
			var entry := rules.style(building_id, style_id).duplicate()
			var costs := {}
			for key: String in COST_ITEMS:
				if entry.get(key, 0) > 0:
					costs[COST_ITEMS[key]] = entry[key]
			entry["costs"] = costs
			types[building_id][style_id] = entry
	return types


static func _own_looks() -> Dictionary:
	var types := {}
	for building_id: StringName in STYLES:
		types[building_id] = STYLES[building_id][&""]
	return types
