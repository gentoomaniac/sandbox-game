class_name ItemTypes
extends RefCounted
## The kinds of item, as data. Keyed by item id; each entry has:
## - name: what the player reads;
## - weight: of one item, in kilograms;
## - stack_limit: how many fit in one inventory slot.
## Optional:
## - tool: the kind of tool it is (HOE ...) and `level`, how good it is (see
##   WorldObjectTypes `harvest_level`);
## - held_sheet: the variant of the character's `held` layer that shows it in the hand;
## - equip_slot: the Equipment slot it is worn in (wearables have a stack limit of 1), and
##   `layer_variant`, the variant of the character layer it shows (see Appearance.dress);
## - plants: seeds or a sapling; the world object type that grows from them, `plants_on` the
##   terrain it needs (soil if not given) and `plants_state` the state the new object starts with.

const HOE := &"hoe"
const AXE := &"axe"
const PICKAXE := &"pickaxe"
const WATERING_CAN := &"watering_can"
const TURNIP_SEEDS := &"turnip_seeds"
const TURNIP := &"turnip"
const LOGS := &"logs"
const STONE := &"stone"
const FIBRE := &"fibre"
const BERRIES := &"berries"
const SAPLING := &"sapling"
const TUNIC := &"tunic"
const SHIRT := &"shirt"
const TROUSERS := &"trousers"
const STRAW_HAT := &"straw_hat"

## Stands for an empty hand or slot where an item id is expected.
const NONE := &""

const DEFAULT_STACK_LIMIT := 99

## The hit points a hit of a tool of each level (the index) takes off. Equal to the level for
## now; a table so it can be tuned per level later.
const POWER_OF_LEVEL := [0, 1, 2, 3]

const ICON_PATH := "res://assets/items/%s.png"
const GROUND_ICON_PATH := "res://assets/ground_items/%s.png"

const _OTHER_TYPES := {
	HOE:
	{
		"name": "Hoe",
		"weight": 2.0,
		"stack_limit": 1,
		"tool": HOE,
		"level": 1,
		"held_sheet": "hoe",
	},
	AXE:
	{
		"name": "Axe",
		"weight": 3.0,
		"stack_limit": 1,
		"tool": AXE,
		"level": 1,
	},
	PICKAXE:
	{
		"name": "Pickaxe",
		"weight": 3.0,
		"stack_limit": 1,
		"tool": PICKAXE,
		"level": 1,
	},
	WATERING_CAN:
	{
		"name": "Watering can",
		"weight": 2.5,
		"stack_limit": 1,
		"tool": WATERING_CAN,
		"level": 1,
	},
	LOGS:
	{
		"name": "Logs",
		"weight": 1.0,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	STONE:
	{
		"name": "Stone",
		"weight": 1.5,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	FIBRE:
	{
		"name": "Fibre",
		"weight": 0.1,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	BERRIES:
	{
		"name": "Berries",
		"weight": 0.05,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	SAPLING:
	{
		"name": "Sapling",
		"weight": 0.5,
		"stack_limit": DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.OAK},
	},
	TUNIC:
	{
		"name": "Tunic",
		"weight": 0.8,
		"stack_limit": 1,
		"equip_slot": Equipment.BODY,
		"layer_variant": "0",
	},
	SHIRT:
	{
		"name": "Shirt",
		"weight": 0.5,
		"stack_limit": 1,
		"equip_slot": Equipment.BODY,
		"layer_variant": "1",
	},
	TROUSERS:
	{
		"name": "Trousers",
		"weight": 0.7,
		"stack_limit": 1,
		"equip_slot": Equipment.LEGS,
		"layer_variant": "0",
	},
	STRAW_HAT:
	{
		"name": "Straw hat",
		"weight": 0.3,
		"stack_limit": 1,
		"equip_slot": Equipment.HEAD,
		"layer_variant": "straw_hat",
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
			"weight": crop["seed_weight"],
			"stack_limit": DEFAULT_STACK_LIMIT,
			"plants": crop_id,
		}
		types[StringName(crop["produce"])] = {
			"name": crop["name"],
			"weight": crop["produce_weight"],
			"stack_limit": DEFAULT_STACK_LIMIT,
		}
	return types
