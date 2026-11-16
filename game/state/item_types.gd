class_name ItemTypes
extends RefCounted
## The kinds of item, as data. Keyed by item id; each entry has:
## - name: what the player reads;
## - description: one line about it for its tooltip (see ItemTooltip);
## - weight: of one item, in kilograms;
## - stack_limit: how many fit in one inventory slot.
## Optional:
## - tool: the kind of tool it is (HOE ...); `level`, how good it is (see WorldObjectTypes
##   `harvest_level`), `power`, the hit points a hit takes off, and `energy_factor`, what its uses
##   cost as a share of the usual, and `numeral`, the Roman numeral of its grade, which the
##   inventory slot draws (see SlotView); every tool comes in five grades, made from
##   data/tools.cfg in `_with_tool_items`;
## - held_sheet: the variant of the character's `held` layer that shows it in the hand;
## - equip_slot: the Equipment slot it is worn in (wearables have a stack limit of 1), and
##   `layer_variant`, the variant of the character layer it shows (see Appearance.dress), and
##   `stats`, {"Warmth": 2, ...} values the tooltip lists (none yet);
## - plants: seeds (of a crop or of a tree); the world object type that grows from them,
##   `plants_on` the terrain it needs (soil if not given) and `plants_state` the state the new
##   object starts with;
## - places: using it puts the world object type of this name on a free tile and takes one away
##   (the chest, the stations).

## The kinds of tool (the `tool` of an item and of the world objects that need one); the items
## are their grades: `tool_item(HOE, 2)` is the iron hoe.
const HOE := &"hoe"
const AXE := &"axe"
const PICKAXE := &"pickaxe"
const WATERING_CAN := &"watering_can"
const SCYTHE := &"scythe"
const SHOVEL := &"shovel"
const HAMMER := &"hammer"
## The tools every new game starts with, rusty iron.
const RUSTY_IRON_HOE := &"rusty_iron_hoe"
const RUSTY_IRON_AXE := &"rusty_iron_axe"
const RUSTY_IRON_PICKAXE := &"rusty_iron_pickaxe"
const RUSTY_IRON_WATERING_CAN := &"rusty_iron_watering_can"
const RUSTY_IRON_SCYTHE := &"rusty_iron_scythe"
const RUSTY_IRON_SHOVEL := &"rusty_iron_shovel"
const RUSTY_IRON_HAMMER := &"rusty_iron_hammer"
const CHEST := &"chest"
const TURNIP_SEEDS := &"turnip_seeds"
const TURNIP := &"turnip"
const LOGS := &"logs"
const STONE := &"stone"
const FIBRE := &"fibre"
const BERRIES := &"berries"
const ACORN := &"acorn"
const SPRUCE_CONE := &"spruce_cone"
const PINE_CONE := &"pine_cone"
const BEECHNUT := &"beechnut"
const BIRCH_CATKIN := &"birch_catkin"
const ALDER_CONE := &"alder_cone"
const WILLOW_CUTTING := &"willow_cutting"
const HAY := &"hay"
const CLAY := &"clay"
const REEDS := &"reeds"
const WAISTCOAT := &"waistcoat"
const SHIRT := &"shirt"
const BREECHES := &"breeches"
const STRAW_HAT := &"straw_hat"
const KNITTED_CAP := &"knitted_cap"
const JACKET := &"jacket"
const CLOGS := &"clogs"
# The stations the player places (task 74).
const WORKBENCH := &"workbench"
const KILN := &"kiln"
const OVEN := &"oven"
## The campfire and the bedroll are the items of the camp objects, which keep their ids.
const FIREPLACE := &"fireplace"
const SLEEPING_BAG := &"sleeping_bag"
# Made at the workbench (task 74).
const PLANKS := &"planks"
const STOOL := &"stool"
const CARVED_CHEST := &"carved_chest"
const SALES_CART := &"sales_cart"
const CUPBOARD := &"cupboard"
## A cross or a stone for a grave in the churchyard (task 102).
const GRAVE_MARKER := &"grave_marker"
# The fisherman's landing (task 103).
const JETTY := &"jetty"
const ROWING_BOAT := &"rowing_boat"
const NET_FRAME := &"net_frame"
const EEL_TRAPS := &"eel_traps"
# The farm yard (task 122).
const DRAW_WELL := &"draw_well"
const NOTICE_BOARD := &"notice_board"
const TROUGH := &"trough"
const HAY_RACK := &"hay_rack"
const FEED_TROUGH := &"feed_trough"
const PEN_FENCE := &"pen_fence"
const PEN_GATE := &"pen_gate"
const PIG_SHELTER := &"pig_shelter"
const WATTLE_FENCE := &"wattle_fence"
const STONE_WALL := &"stone_wall"
const SCARECROW := &"scarecrow"
# The ways (#62).
const PLANK_WALK := &"plank_walk"
const STONE_PATH := &"stone_path"
# Dug-up bushes (task 208).
const BERRY_BUSH := &"berry_bush"
const SHRUB := &"shrub"
const FERN_BUSH := &"fern_bush"
const EGG := &"egg"
# The mason's (task 74).
const RAW_BRICK := &"raw_brick"
const BRICK := &"brick"
# Cooked at the hearth (task 74).
const ROAST_TURNIP := &"roast_turnip"
const POTTAGE := &"pottage"
const PEA_SOUP := &"pea_soup"
const BUCKWHEAT_PANCAKES := &"buckwheat_pancakes"
const FLOUR := &"flour"
const BREAD := &"bread"
const BERRY_TART := &"berry_tart"
const FEAST_CAKE := &"feast_cake"
## Given to a dog, it makes the dog follow the player (task 79).
const BONE := &"bone"
## Put on a horse, it lets the player ride the horse (task 81).
const SADDLE := &"saddle"
## Beeswax (task 231). Only the console gives it for now; the bee hives that make it come later.
const WAX := &"wax"
## Wax round a fibre wick. A lantern burns it down.
const CANDLE := &"candle"
## Carried and lit, it lights the dark around the player (task 177; see PlayerState
## `is_lantern_lit`).
const LANTERN := &"lantern"

## Stands for an empty hand or slot where an item id is expected.
const NONE := &""

const DEFAULT_STACK_LIMIT := 99

## What every crop seed says about itself; the crop it grows is in the tooltip anyway.
const SEED_DESCRIPTION := "Sow it and keep it watered until harvest."

## The tool and harvest levels there are: 0 (by hand) to 3.
const LEVEL_COUNT := 4

## What each kind of tool is called and does; the grades make an item of each.
const _TOOL_KINDS := {
	HOE: {"name": "hoe", "description": "Breaks up grass into tilled soil for planting."},
	AXE: {"name": "axe", "description": "Fells trees and chops stumps."},
	PICKAXE: {"name": "pickaxe", "description": "Breaks stones; boulders need a stronger one."},
	WATERING_CAN: {"name": "watering can", "description": "Waters tilled soil so crops grow."},
	SCYTHE: {"name": "scythe", "description": "Mows tall grass into hay and cuts reeds."},
	SHOVEL: {"name": "shovel", "description": "Digs up grass and clay."},
	HAMMER: {"name": "hammer", "description": "Builds houses and other buildings."},
}

const ICON_PATH := "res://assets/items/%s.png"
const GROUND_ICON_PATH := "res://assets/ground_items/%s.png"

## The folder of the topic scripts that define the items (see CatalogTopics).
const TOPICS_DIR := "res://game/state/items"
const _OWN_SOURCE := "res://game/state/item_types.gd"

const _OTHER_TYPES := {
	WATTLE_FENCE:
	{
		"name": "Wattle fence",
		"description": "Hazel rods woven between stakes, a light fence for a field or a yard.",
		"weight": 1.0,
		"stack_limit": 20,
		"places": WorldObjectTypes.WATTLE_FENCE,
	},
	STONE_WALL:
	{
		"name": "Stone wall",
		"description": "A piece of dry stone wall, fieldstones stacked without mortar.",
		"weight": 4.5,
		"stack_limit": 10,
		"places": WorldObjectTypes.STONE_WALL,
	},
	PLANK_WALK:
	{
		"name": "Plank walk",
		"description":
		"A piece of boardwalk. Laid on grass or mud, it never wears or turns to mud.",
		"weight": 1.0,
		"stack_limit": 20,
		"places": WorldObjectTypes.PLANK_WALK,
	},
	STONE_PATH:
	{
		"name": "Stone path",
		"description": "Cobbles set in the earth. Laid on grass, it never wears or turns to mud.",
		"weight": 3.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.STONE_PATH,
	},
	BERRY_BUSH:
	{
		"name": "Berry bush",
		"description": "A dug-up berry bush. Plant it on grass; it bears again after a few days.",
		"weight": 5.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.BERRY_BUSH,
	},
	SHRUB:
	{
		"name": "Shrub",
		"description": "A dug-up shrub. Plant it on grass.",
		"weight": 4.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.SHRUB,
	},
	FERN_BUSH:
	{
		"name": "Fern",
		"description": "A dug-up fern. Planted in winter, it stays hidden until spring.",
		"weight": 2.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.FERN_BUSH,
	},
	BONE:
	{
		"name": "Bone",
		"description": "A meaty bone. Give it to a dog, and it follows you for a while.",
		"weight": 0.3,
		"stack_limit": 20,
	},
	SADDLE:
	{
		"name": "Saddle",
		"description": "A riding saddle of leather. Put it on a horse, and you can ride it.",
		"weight": 8.0,
		"stack_limit": 1,
	},
	LANTERN:
	{
		"name": "Lantern",
		"description": "A horn lantern. Hold it and use it to fit a candle, then to light it.",
		"weight": 1.0,
		"stack_limit": 1,
		"held_sheet": "lantern",
	},
}

## What went wrong while the crop items were added to the fixed ones: an id used twice (see
## CatalogCheck).
static var build_problems: Array[String] = []

## Every type: the fixed ones above, the tools in their grades (data/tools.cfg) and the seeds and
## produce of the crops in data/crops.cfg. Read-only, all the way down.
# The name is that of a constant, but the items made from the files are only known once they are
# read.
# gdlint: ignore=class-variable-name
static var TYPES := _with_crop_items(_with_tool_items(_declared_types()))


## The item's 32x32 icon, which the UI shows at half size (see tools/art/items.py).
static func icon_path(item: StringName) -> String:
	return ICON_PATH % item


## The item's 16x16 picture for when it lies on the ground (see tools/art/items.py).
static func ground_icon_path(item: StringName) -> String:
	return GROUND_ICON_PATH % item


## The world object type that using the item puts down, or &"" if it puts none down.
static func placed_object(item: StringName) -> StringName:
	return TYPES.get(item, {}).get("places", &"")


## The item that puts a world object type down, or &"" for what no item places (a tree, a rock):
## what the player placed can be taken down again.
static func item_placing(object_type: StringName) -> StringName:
	for item: StringName in TYPES:
		if TYPES[item].get("places") == object_type:
			return item
	return &""


## The id of a kind of tool in a grade (0, rusty iron, to the best): `iron_hoe`.
static func tool_item(tool_kind: StringName, grade: int) -> StringName:
	return StringName("%s_%s" % [ToolGradeRules.default_rules().grade_ids()[grade], tool_kind])


## How many hit points one hit of this tool takes off.
static func tool_power(tool_item_id: StringName) -> int:
	return TYPES[tool_item_id]["power"]


## What a use of this item costs in energy, as a share of the cost of the use: 1 for what is not
## a tool.
static func energy_factor(item: StringName) -> float:
	return TYPES.get(item, {}).get("energy_factor", 1.0)


## The name of the kind of tool the item is ("axe"), for what it needs ("Needs a better axe").
static func tool_name(tool_item_id: StringName) -> String:
	return _TOOL_KINDS[TYPES[tool_item_id]["tool"]]["name"]


## The items of the topic scripts, checked for ids two of them define.
static func _declared_types() -> Dictionary:
	var sources := {_OWN_SOURCE: _OTHER_TYPES}
	sources.merge(CatalogTopics.read_folder(TOPICS_DIR, build_problems))
	return CatalogTopics.merged("item", sources, build_problems)


## The tools in every grade of data/tools.cfg, added to the fixed types.
static func _with_tool_items(other_types: Dictionary) -> Dictionary:
	var types := other_types.duplicate()
	var rules := ToolGradeRules.default_rules()
	build_problems.append_array(rules.problems())
	if not rules.is_valid():
		return types
	for tool_kind: StringName in _TOOL_KINDS:
		for grade in rules.grade_ids().size():
			var values := rules.grade(rules.grade_ids()[grade])
			var id := tool_item(tool_kind, grade)
			build_problems.append_array(CatalogCheck.reused_ids("item", types, [id]))
			types[id] = {
				"name": "%s %s" % [values["name"], _TOOL_KINDS[tool_kind]["name"]],
				"description": _TOOL_KINDS[tool_kind]["description"],
				"weight": 0.0,
				"stack_limit": 1,
				"tool": tool_kind,
				"level": values["level"],
				"power": values["power"],
				"energy_factor": values["energy_factor"],
				"numeral": values["numeral"],
				"held_sheet": id,
			}
	return types


static func _with_crop_items(other_types: Dictionary) -> Dictionary:
	var types := other_types.duplicate()
	var rules := CropRules.default_rules()
	var crop_item_ids: Array[StringName] = []
	for crop_id in rules.crop_ids():
		crop_item_ids.append(StringName(rules.crop(crop_id)["seed"]))
		crop_item_ids.append(StringName(rules.crop(crop_id)["produce"]))
	build_problems.append_array(CatalogCheck.reused_ids("item", other_types, crop_item_ids))
	for crop_id in rules.crop_ids():
		var crop := rules.crop(crop_id)
		types[StringName(crop["seed"])] = {
			"name": crop["seed_name"],
			"description": SEED_DESCRIPTION,
			"weight": crop["seed_weight"],
			"stack_limit": DEFAULT_STACK_LIMIT,
			"plants": crop_id,
		}
		types[StringName(crop["produce"])] = {
			"name": crop["name"],
			"description": crop["description"],
			"weight": crop["produce_weight"],
			"stack_limit": DEFAULT_STACK_LIMIT,
		}
	ReadOnly.deep(types)
	return types
