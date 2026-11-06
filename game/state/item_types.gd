class_name ItemTypes
extends RefCounted
## The kinds of item, as data. Keyed by item id; each entry has:
## - name: what the player reads;
## - description: one line about it for its tooltip (see ItemTooltip);
## - weight: of one item, in kilograms;
## - stack_limit: how many fit in one inventory slot.
## Optional:
## - tool: the kind of tool it is (HOE ...) and `level`, how good it is (see
##   WorldObjectTypes `harvest_level`);
## - held_sheet: the variant of the character's `held` layer that shows it in the hand;
## - equip_slot: the Equipment slot it is worn in (wearables have a stack limit of 1), and
##   `layer_variant`, the variant of the character layer it shows (see Appearance.dress), and
##   `stats`, {"Warmth": 2, ...} values the tooltip lists (none yet);
## - plants: seeds (of a crop or of a tree); the world object type that grows from them,
##   `plants_on` the terrain it needs (soil if not given) and `plants_state` the state the new
##   object starts with;
## - places: using it puts the world object type of this name on a free tile and takes one away
##   (the chest).

const HOE := &"hoe"
const AXE := &"axe"
const PICKAXE := &"pickaxe"
const WATERING_CAN := &"watering_can"
const SCYTHE := &"scythe"
const SHOVEL := &"shovel"
const HAMMER := &"hammer"
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
const HAY := &"hay"
const CLAY := &"clay"
const REEDS := &"reeds"
const TUNIC := &"tunic"
const SHIRT := &"shirt"
const TROUSERS := &"trousers"
const STRAW_HAT := &"straw_hat"
const KNITTED_CAP := &"knitted_cap"
const JACKET := &"jacket"
const CLOGS := &"clogs"

## Stands for an empty hand or slot where an item id is expected.
const NONE := &""

const DEFAULT_STACK_LIMIT := 99

## What every crop seed says about itself; the crop it grows is in the tooltip anyway.
const SEED_DESCRIPTION := "Sow it and keep it watered until harvest."

## The hit points a hit of a tool of each level (the index) takes off. Equal to the level for
## now; a table so it can be tuned per level later.
const POWER_OF_LEVEL := [0, 1, 2, 3]

const ICON_PATH := "res://assets/items/%s.png"
const GROUND_ICON_PATH := "res://assets/ground_items/%s.png"

const _OTHER_TYPES := {
	HOE:
	{
		"name": "Hoe",
		"description": "Breaks up grass into tilled soil for planting.",
		"weight": 2.0,
		"stack_limit": 1,
		"tool": HOE,
		"level": 1,
		"held_sheet": "hoe",
	},
	AXE:
	{
		"name": "Axe",
		"description": "Fells trees and chops stumps.",
		"weight": 3.0,
		"stack_limit": 1,
		"tool": AXE,
		"level": 1,
	},
	PICKAXE:
	{
		"name": "Pickaxe",
		"description": "Breaks stones; boulders need a stronger one.",
		"weight": 3.0,
		"stack_limit": 1,
		"tool": PICKAXE,
		"level": 1,
	},
	WATERING_CAN:
	{
		"name": "Watering can",
		"description": "Waters tilled soil so crops grow.",
		"weight": 2.5,
		"stack_limit": 1,
		"tool": WATERING_CAN,
		"level": 1,
	},
	SCYTHE:
	{
		"name": "Scythe",
		"description": "Mows tall grass into hay and cuts reeds.",
		"weight": 2.0,
		"stack_limit": 1,
		"tool": SCYTHE,
		"level": 1,
	},
	SHOVEL:
	{
		"name": "Shovel",
		"description": "Digs up grass and clay.",
		"weight": 2.5,
		"stack_limit": 1,
		"tool": SHOVEL,
		"level": 1,
	},
	HAMMER:
	{
		"name": "Hammer",
		"description": "Builds houses and other buildings.",
		"weight": 2.0,
		"stack_limit": 1,
		"tool": HAMMER,
		"level": 1,
	},
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
	TUNIC:
	{
		"name": "Tunic",
		"description": "A plain tunic that covers your body.",
		"weight": 0.6,
		"stack_limit": 1,
		"equip_slot": Equipment.BODY,
		"layer_variant": "0",
	},
	SHIRT:
	{
		"name": "Shirt",
		"description": "A light shirt.",
		"weight": 0.3,
		"stack_limit": 1,
		"equip_slot": Equipment.BODY,
		"layer_variant": "1",
	},
	TROUSERS:
	{
		"name": "Trousers",
		"description": "Simple trousers.",
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
}

## Every type: the fixed ones above and the seeds and produce of the crops in data/crops.cfg.
# The name is that of a constant, but the crop items are only known once the file is read.
static var TYPES := _with_crop_items(_OTHER_TYPES)  # gdlint: ignore=class-variable-name


## The item's 16x16 picture (see tools/art/items.py).
static func icon_path(item: StringName) -> String:
	return ICON_PATH % item


## The item's 8x8 picture for when it lies on the ground (see tools/art/items.py).
static func ground_icon_path(item: StringName) -> String:
	return GROUND_ICON_PATH % item


## The world object type that using the item puts down, or &"" if it puts none down.
static func placed_object(item: StringName) -> StringName:
	return TYPES.get(item, {}).get("places", &"")


## How many hit points one hit of this tool takes off.
static func tool_power(tool_item: StringName) -> int:
	return POWER_OF_LEVEL[TYPES[tool_item]["level"]]


static func _with_crop_items(other_types: Dictionary) -> Dictionary:
	var types := other_types.duplicate()
	var rules := CropRules.default_rules()
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
	return types
