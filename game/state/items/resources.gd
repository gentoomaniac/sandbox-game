class_name ItemResources
extends RefCounted
## The materials of the game as data, loaded into ItemTypes `TYPES` (see there for the entries):
## what is gathered, cut, fired or spun, and the tree seeds and cuttings that grow a tree.

const TYPES := {
	&"hay":
	{
		"name": "Hay",
		"description": "Dry cut grass. Good for stuffing and thatch.",
		"weight": 0.2,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"reeds":
	{
		"name": "Reeds",
		"description": "Tough stalks from the waterside.",
		"weight": 0.3,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"clay":
	{
		"name": "Clay",
		"description": "Wet, sticky earth from the riverbank.",
		"weight": 1.0,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"logs":
	{
		"name": "Logs",
		"description": "Rough timber from a felled tree.",
		"weight": 1.0,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"stone":
	{
		"name": "Stone",
		"description": "A solid chunk of rock for building.",
		"weight": 1.5,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"fibre":
	{
		"name": "Fibre",
		"description": "Stringy plant fibre.",
		"weight": 0.1,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"berries":
	{
		"name": "Berries",
		"description": "Wild berries. Sweet and quick to eat.",
		"weight": 0.05,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"acorn":
	{
		"name": "Acorn",
		"description": "The seed of an oak.",
		"weight": 0.05,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.OAK},
	},
	&"spruce_cone":
	{
		"name": "Spruce cone",
		"description": "The seed of a spruce.",
		"weight": 0.05,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.SPRUCE},
	},
	&"pine_cone":
	{
		"name": "Pine cone",
		"description": "The seed of a pine.",
		"weight": 0.05,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.PINE},
	},
	&"beechnut":
	{
		"name": "Beechnut",
		"description": "The seed of a beech, from its prickly husk.",
		"weight": 0.02,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.BEECH},
	},
	&"birch_catkin":
	{
		"name": "Birch catkin",
		"description": "The seed catkin of a birch: it crumbles into tiny winged seeds.",
		"weight": 0.01,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.BIRCH},
	},
	&"alder_cone":
	{
		"name": "Alder cone",
		"description": "A tiny woody cone of an alder. Its seeds float on the water.",
		"weight": 0.01,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.ALDER},
	},
	# Willows are not grown from seed but from cut rods stuck in the ground.
	&"willow_cutting":
	{
		"name": "Willow cutting",
		"description": "A rod cut from a willow. Stuck in the ground, it takes root.",
		"weight": 0.05,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
		"plants": WorldObjectTypes.SAPLING,
		"plants_on": Tile.Terrain.GRASS,
		"plants_state": {"tree": WorldObjectTypes.WILLOW},
	},
	&"egg":
	{
		"name": "Egg",
		"description": "A hen's egg, still warm from the nest.",
		"weight": 0.06,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"planks":
	{
		"name": "Planks",
		"description": "Boards split and planed from a log.",
		"weight": 0.5,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"raw_brick":
	{
		"name": "Raw brick",
		"description": "Clay moulded into a brick and dried. The kiln fires it hard.",
		"weight": 1.0,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"brick":
	{
		"name": "Brick",
		"description": "A fired red brick, as the marsh brickworks make them.",
		"weight": 1.0,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"wax":
	{
		"name": "Wax",
		"description": "A cake of beeswax. Make candles of it.",
		"weight": 0.2,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
	&"candle":
	{
		"name": "Candle",
		"description": "Wax round a fibre wick. It burns in a lantern.",
		"weight": 0.1,
		"stack_limit": ItemTypes.DEFAULT_STACK_LIMIT,
	},
}
