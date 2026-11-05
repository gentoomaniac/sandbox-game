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
## - plants: seeds; the world object type that grows from them.

const HOE := &"hoe"
const AXE := &"axe"
const PICKAXE := &"pickaxe"
const WATERING_CAN := &"watering_can"
const TURNIP_SEEDS := &"turnip_seeds"
const TURNIP := &"turnip"

## Stands for an empty hand or slot where an item id is expected.
const NONE := &""

const DEFAULT_STACK_LIMIT := 99

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
}


## The item's 16x16 picture (see tools/art/items.py).
static func icon_path(item: StringName) -> String:
	return ICON_PATH % item
