class_name BuildingTypes
extends RefCounted
## The kinds of building, as data from data/buildings.cfg (see there and BuildingRules).
## Keyed by type name; each entry has the keys of the file, and also:
## - costs: the materials placing it takes, item id to count (only those that are not 0).

const SHACK := &"shack"
const KATE := &"kate"
const LONGHOUSE := &"longhouse"
const BARN := &"barn"

## The material of each `cost_<material>` key of the file.
const COST_ITEMS := {
	"cost_logs": ItemTypes.LOGS,
	"cost_stone": ItemTypes.STONE,
	"cost_clay": ItemTypes.CLAY,
	"cost_reeds": ItemTypes.REEDS,
}

# The name is that of a constant, but the types are only known once the file is read.
static var TYPES := _from_rules(BuildingRules.default_rules())  # gdlint: ignore=class-variable-name


## The building ids, in the order of the file.
static func ids() -> Array[StringName]:
	return BuildingRules.default_rules().building_ids()


static func _from_rules(rules: BuildingRules) -> Dictionary:
	var types := {}
	for building_id in rules.building_ids():
		var building := rules.building(building_id).duplicate()
		var costs := {}
		for key: String in COST_ITEMS:
			if building.get(key, 0) > 0:
				costs[COST_ITEMS[key]] = building[key]
		building["costs"] = costs
		types[building_id] = building
	return types
