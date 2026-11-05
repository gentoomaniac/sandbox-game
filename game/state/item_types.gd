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
## - plants: seeds or a sapling; the world object type that grows from them, `plants_on` the
##   terrain it needs (soil if not given) and `plants_state` the state the new object starts with.

const HOE := &"hoe"
const AXE := &"axe"
const PICKAXE := &"pickaxe"
const WATERING_CAN := &"watering_can"
const TURNIP_SEEDS := &"turnip_seeds"
const TURNIP := &"turnip"
const WOOD := &"wood"
const STONE := &"stone"
const FIBRE := &"fibre"
const BERRIES := &"berries"
const SAPLING := &"sapling"

## Stands for an empty hand or slot where an item id is expected.
const NONE := &""

const DEFAULT_STACK_LIMIT := 99

## The hit points a hit of a tool of each level (the index) takes off. Equal to the level for
## now; a table so it can be tuned per level later.
const POWER_OF_LEVEL := [0, 1, 2, 3]

const ICON_PATH := "res://assets/items/%s.png"

const TYPES := {
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
	TURNIP_SEEDS:
	{
		"name": "Turnip seeds",
		"weight": 0.02,
		"stack_limit": DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.TURNIP,
	},
	TURNIP:
	{
		"name": "Turnip",
		"weight": 0.4,
		"stack_limit": DEFAULT_STACK_LIMIT,
	},
	WOOD:
	{
		"name": "Wood",
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
}


## The item's 16x16 picture (see tools/art/items.py).
static func icon_path(item: StringName) -> String:
	return ICON_PATH % item


## How many hit points one hit of this tool takes off.
static func tool_power(tool_item: StringName) -> int:
	return POWER_OF_LEVEL[TYPES[tool_item]["level"]]
