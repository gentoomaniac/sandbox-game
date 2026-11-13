class_name ItemTypes
extends RefCounted
## The kinds of item, as data. Keyed by item id; each entry has:
## - name: what the player reads;
## - description: one line about it for its tooltip (see ItemTooltip);
## - weight: of one item, in kilograms;
## - stack_limit: how many fit in one inventory slot.
## Optional:
## - tool: the kind of tool it is (HOE ...) and `level`, how good it is (see
##   WorldObjectTypes `harvest_level`); every tool comes in five grades, made from
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
const TROUGH := &"trough"
const HAY_RACK := &"hay_rack"
const FEED_TROUGH := &"feed_trough"
const PEN_FENCE := &"pen_fence"
const PEN_GATE := &"pen_gate"
const PIG_SHELTER := &"pig_shelter"
const WATTLE_FENCE := &"wattle_fence"
const STONE_WALL := &"stone_wall"
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
## Carried and lit, it lights the dark around the player (task 177; see PlayerState
## `is_lantern_lit`).
const LANTERN := &"lantern"

## Stands for an empty hand or slot where an item id is expected.
const NONE := &""

const DEFAULT_STACK_LIMIT := 99

## What every crop seed says about itself; the crop it grows is in the tooltip anyway.
const SEED_DESCRIPTION := "Sow it and keep it watered until harvest."

## The hit points a hit of a tool of each level (the index) takes off. Equal to the level for
## now; a table so it can be tuned per level later.
const POWER_OF_LEVEL := [0, 1, 2, 3]

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

const _OTHER_TYPES := {
	CHEST:
	{
		"name": "Chest",
		"description": "Stores items. Place it outside or in a house; the axe takes it down.",
		"weight": 4.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.CHEST,
	},
	HAY:
	{
		"name": "Hay",
		"description": "Dry cut grass. Good for stuffing and thatch.",
		"weight": 0.2,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	REEDS:
	{
		"name": "Reeds",
		"description": "Tough stalks from the waterside.",
		"weight": 0.3,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	CLAY:
	{
		"name": "Clay",
		"description": "Wet, sticky earth from the riverbank.",
		"weight": 1.0,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	LOGS:
	{
		"name": "Logs",
		"description": "Rough timber from a felled tree.",
		"weight": 1.0,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	STONE:
	{
		"name": "Stone",
		"description": "A solid chunk of rock for building.",
		"weight": 1.5,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	FIBRE:
	{
		"name": "Fibre",
		"description": "Stringy plant fibre.",
		"weight": 0.1,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	BERRIES:
	{
		"name": "Berries",
		"description": "Wild berries. Sweet and quick to eat.",
		"weight": 0.05,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	ACORN:
	{
		"name": "Acorn",
		"description": "The seed of an oak.",
		"weight": 0.05,
		"stack_limit": DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.OAK},
	},
	SPRUCE_CONE:
	{
		"name": "Spruce cone",
		"description": "The seed of a spruce.",
		"weight": 0.05,
		"stack_limit": DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.SPRUCE},
	},
	PINE_CONE:
	{
		"name": "Pine cone",
		"description": "The seed of a pine.",
		"weight": 0.05,
		"stack_limit": DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.PINE},
	},
	BEECHNUT:
	{
		"name": "Beechnut",
		"description": "The seed of a beech, from its prickly husk.",
		"weight": 0.02,
		"stack_limit": DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.BEECH},
	},
	BIRCH_CATKIN:
	{
		"name": "Birch catkin",
		"description": "The seed catkin of a birch: it crumbles into tiny winged seeds.",
		"weight": 0.01,
		"stack_limit": DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.BIRCH},
	},
	ALDER_CONE:
	{
		"name": "Alder cone",
		"description": "A tiny woody cone of an alder. Its seeds float on the water.",
		"weight": 0.01,
		"stack_limit": DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.ALDER},
	},
	# Willows are not grown from seed but from cut rods stuck in the ground.
	WILLOW_CUTTING:
	{
		"name": "Willow cutting",
		"description": "A rod cut from a willow. Stuck in the ground, it takes root.",
		"weight": 0.05,
		"stack_limit": DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.WILLOW},
	},
	WAISTCOAT:
	{
		"name": "Waistcoat",
		"description": "A red wool waistcoat with tin buttons, over a linen shirt.",
		"weight": 0.6,
		"stack_limit": 1,
		"equip_slot": Equipment.BODY,
		"layer_variant": "0",
	},
	SHIRT:
	{
		"name": "Linen shirt",
		"description": "A plain linen shirt, cool in the summer sun.",
		"weight": 0.3,
		"stack_limit": 1,
		"equip_slot": Equipment.BODY,
		"layer_variant": "1",
	},
	BREECHES:
	{
		"name": "Breeches",
		"description": "Brown wool knee breeches, with white knitted stockings.",
		"weight": 0.5,
		"stack_limit": 1,
		"equip_slot": Equipment.LEGS,
		"layer_variant": "0",
	},
	STRAW_HAT:
	{
		"name": "Straw hat",
		"description": "Keeps the sun off your head.",
		"weight": 0.3,
		"stack_limit": 1,
		"equip_slot": Equipment.HEAD,
		"layer_variant": "straw_hat",
	},
	KNITTED_CAP:
	{
		"name": "Knitted cap",
		"description": "A red wool stocking cap, warm in the wind.",
		"weight": 0.1,
		"stack_limit": 1,
		"equip_slot": Equipment.HEAD,
		"layer_variant": "knitted_cap",
	},
	JACKET:
	{
		"name": "Jacket",
		"description": "A short jacket of blue wool, worn open over the waistcoat.",
		"weight": 0.5,
		"stack_limit": 1,
		"equip_slot": Equipment.COAT,
		"layer_variant": "jacket",
	},
	CLOGS:
	{
		"name": "Clogs",
		"description": "Wooden clogs, for the fields and the mud.",
		"weight": 0.3,
		"stack_limit": 1,
		"equip_slot": Equipment.FEET,
		"layer_variant": "clogs",
	},
	WORKBENCH:
	{
		"name": "Workbench",
		"description": "A joiner's bench. Wood is worked here, and clay moulded.",
		"weight": 8.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.WORKBENCH,
	},
	KILN:
	{
		"name": "Kiln",
		"description": "A small clay kiln that fires bricks overnight. It stands outdoors.",
		"weight": 15.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.KILN,
	},
	OVEN:
	{
		"name": "Bake oven",
		"description": "A brick oven for bread. It stands outdoors or in a house.",
		"weight": 15.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.OVEN,
	},
	FIREPLACE:
	{
		"name": "Campfire",
		"description":
		"A ring of stones round a fire; cook at it. It stands outdoors; the hammer takes it down.",
		"weight": 6.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.FIREPLACE,
	},
	SLEEPING_BAG:
	{
		"name": "Bedroll",
		"description":
		"A straw sack and a wool blanket to sleep on. It lies outdoors; the hammer takes it down.",
		"weight": 3.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.SLEEPING_BAG,
	},
	PLANKS:
	{
		"name": "Planks",
		"description": "Boards split and planed from a log.",
		"weight": 0.5,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	STOOL:
	{
		"name": "Stool",
		"description": "A three-legged stool. It stands in a house.",
		"weight": 1.5,
		"stack_limit": 10,
		"places": WorldObjectTypes.STOOL,
	},
	CARVED_CHEST:
	{
		"name": "Carved chest",
		"description": "A painted chest in the Frisian way, roomier than a plain one.",
		"weight": 6.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.CARVED_CHEST,
	},
	RAW_BRICK:
	{
		"name": "Raw brick",
		"description": "Clay moulded into a brick and dried. The kiln fires it hard.",
		"weight": 1.0,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	BRICK:
	{
		"name": "Brick",
		"description": "A fired red brick, as the marsh brickworks make them.",
		"weight": 1.0,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	CUPBOARD:
	{
		"name": "Joined cupboard",
		"description":
		"An oak cupboard with panelled doors, a master's piece. It stands in a house.",
		"weight": 10.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.CUPBOARD,
	},
	GRAVE_MARKER:
	{
		"name": "Grave marker",
		"description": "An oak cross for a grave. It stands outdoors.",
		"weight": 10.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.GRAVE,
	},
	JETTY:
	{
		"name": "Jetty",
		"description":
		"A piece of plank jetty on oak piles. Laid over water or mud, it is walked on.",
		"weight": 6.0,
		"stack_limit": 20,
		"places": WorldObjectTypes.JETTY,
	},
	ROWING_BOAT:
	{
		"name": "Rowing boat",
		"description": "A flat-bottomed boat for the tideways. It lies on water or mud.",
		"weight": 40.0,
		"stack_limit": 1,
		"places": WorldObjectTypes.ROWING_BOAT,
	},
	NET_FRAME:
	{
		"name": "Net frame",
		"description": "Two forked posts and a pole, with a fishing net hung on it to dry.",
		"weight": 8.0,
		"stack_limit": 5,
		"places": WorldObjectTypes.NET_FRAME,
	},
	EEL_TRAPS:
	{
		"name": "Eel traps",
		"description": "Wicker traps for eels, laid in the tideways at night.",
		"weight": 2.0,
		"stack_limit": 10,
		"places": WorldObjectTypes.EEL_TRAPS,
	},
	DRAW_WELL:
	{
		"name": "Draw well",
		"description": "A fieldstone well with a sweep and a bucket. It stands outdoors.",
		"weight": 40.0,
		"stack_limit": 1,
		"places": WorldObjectTypes.DRAW_WELL,
	},
	EGG:
	{
		"name": "Egg",
		"description": "A hen's egg, still warm from the nest.",
		"weight": 0.06,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	TROUGH:
	{
		"name": "Trough",
		"description": "An oak plank trough for the animals' water. It stands outdoors.",
		"weight": 25.0,
		"stack_limit": 2,
		"places": WorldObjectTypes.TROUGH,
	},
	HAY_RACK:
	{
		"name": "Hay rack",
		"description": "Oak posts with slats to keep hay for the animals. It stands outdoors.",
		"weight": 25.0,
		"stack_limit": 2,
		"places": WorldObjectTypes.HAY_RACK,
	},
	FEED_TROUGH:
	{
		"name": "Feeding trough",
		"description": "An oak plank trough for the animals' feed. It stands outdoors.",
		"weight": 25.0,
		"stack_limit": 2,
		"places": WorldObjectTypes.FEED_TROUGH,
	},
	PEN_FENCE:
	{
		"name": "Pen fence",
		"description": "Split oak rails on a post, a piece of fence for a pig pen.",
		"weight": 4.0,
		"stack_limit": 20,
		"places": WorldObjectTypes.PEN_FENCE,
	},
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
	PEN_GATE:
	{
		"name": "Pen gate",
		"description": "A gate for a pig pen. Shut, it lets you through and keeps the animals in.",
		"weight": 10.0,
		"stack_limit": 4,
		"places": WorldObjectTypes.PEN_GATE,
	},
	PIG_SHELTER:
	{
		"name": "Pig shelter",
		"description": "A lean-to of boards under reed thatch for the pigs. It stands outdoors.",
		"weight": 40.0,
		"stack_limit": 1,
		"places": WorldObjectTypes.PIG_SHELTER,
	},
	ROAST_TURNIP:
	{
		"name": "Roast turnip",
		"description": "A turnip roasted in the embers. Sweeter than raw.",
		"weight": 0.4,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	POTTAGE:
	{
		"name": "Pottage",
		"description": "Cabbage, carrot and onion stewed in the pot over the fire.",
		"weight": 0.5,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	PEA_SOUP:
	{
		"name": "Pea soup",
		"description": "Thick soup of peas and onion, the coast's daily fare.",
		"weight": 0.5,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	BUCKWHEAT_PANCAKES:
	{
		"name": "Buckwheat pancakes",
		"description": "Buckwheat ground and fried thin in the pan, the Geest's pancakes.",
		"weight": 0.3,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	FLOUR:
	{
		"name": "Flour",
		"description": "Grain ground in a hand quern. Bread needs it.",
		"weight": 0.5,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	BREAD:
	{
		"name": "Bread",
		"description": "A round loaf from the oven, the daily bread of the coast.",
		"weight": 0.5,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	BERRY_TART:
	{
		"name": "Berry tart",
		"description": "Berries baked in pastry, a treat for a feast day.",
		"weight": 0.4,
		"stack_limit": DEFAULT_STACK_LIMIT,
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
		"description": "A horn lantern with a tallow candle. Hold it and use it to light it.",
		"weight": 1.0,
		"stack_limit": 1,
		"held_sheet": "lantern",
	},
	FEAST_CAKE:
	{
		"name": "Feast cake",
		"description": "A tall cake with strawberries, baked for a wedding or the harvest feast.",
		"weight": 0.8,
		"stack_limit": DEFAULT_STACK_LIMIT,
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
static var TYPES := _with_crop_items(_with_tool_items(_OTHER_TYPES))


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
	return POWER_OF_LEVEL[TYPES[tool_item_id]["level"]]


## The name of the kind of tool the item is ("axe"), for what it needs ("Needs a better axe").
static func tool_name(tool_item_id: StringName) -> String:
	return _TOOL_KINDS[TYPES[tool_item_id]["tool"]]["name"]


## The tools in every grade of data/tools.cfg, added to the fixed types.
static func _with_tool_items(other_types: Dictionary) -> Dictionary:
	var types := other_types.duplicate()
	var rules := ToolGradeRules.default_rules()
	build_problems.append_array(rules.problems())
	if not rules.is_valid():
		return types
	for tool_kind: StringName in _TOOL_KINDS:
		for grade in rules.grade_ids().size():
			var grade_name: String = rules.grade(rules.grade_ids()[grade])["name"]
			var id := tool_item(tool_kind, grade)
			build_problems.append_array(CatalogCheck.reused_ids("item", types, [id]))
			types[id] = {
				"name": "%s %s" % [grade_name, _TOOL_KINDS[tool_kind]["name"]],
				"description": _TOOL_KINDS[tool_kind]["description"],
				"weight": 0.0,
				"stack_limit": 1,
				"tool": tool_kind,
				"level": 1,
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
