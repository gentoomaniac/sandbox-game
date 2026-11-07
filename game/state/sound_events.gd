class_name SoundEvents
extends RefCounted
## Which sound event a happening in the game makes: the footstep for the ground underfoot,
## the work sound of a tool hit or a use. Plain functions of what happened; the events are the
## ones in SoundRules.EVENTS. An empty name means the happening is silent.


## The step on a tile. Snow lies over anything, ice is frozen water, a floodplain is sand,
## the tidal mud squelches like wetland.
## Indoors the clogs clack on the brick floor as on wood, and a clay floor is soil.
static func footstep(
	terrain: Tile.Terrain, is_frozen: bool, is_snowed: bool, is_indoors: bool
) -> StringName:
	if terrain == Tile.Terrain.CLAY_FLOOR:
		return &"step_soil"
	if is_indoors or terrain == Tile.Terrain.FLOOR:
		return &"step_wood"
	if is_snowed:
		return &"step_snow"
	match terrain:
		Tile.Terrain.WATER, Tile.Terrain.SEA:
			# Unfrozen water can't be walked on, so this is only a fallback.
			return &"step_ice" if is_frozen else &"step_grass"
		Tile.Terrain.WETLAND, Tile.Terrain.MUD:
			return &"step_wetland"
		Tile.Terrain.FLOODPLAIN:
			return &"step_sand"
		Tile.Terrain.SOIL:
			return &"step_soil"
	return &"step_grass"


## The sound of a tool hit on an object of this type (see WorldObjectTypes). `is_finished` is
## whether the hit took the object down: a stone then breaks. A felled tree's own sound, its fall,
## is played when it lands (see GameSounds), so the felling blow is still a chop.
static func hit(object_type: Dictionary, is_finished: bool) -> StringName:
	match object_type.get("tool"):
		ItemTypes.AXE:
			return &"axe_chop"
		ItemTypes.PICKAXE:
			return &"stone_break" if is_finished else &"pickaxe_hit"
	return &""


## The sound of a use of the held item that is not a hit (those are heard as the object being
## hit, see `hit`). A scythe swings even when it mows nothing.
static func use(result: ToolUse.Use, held_tool: StringName) -> StringName:
	match result:
		ToolUse.Use.TILL:
			return &"hoe_till"
		ToolUse.Use.PLANT:
			return &"plant"
		ToolUse.Use.HARVEST, ToolUse.Use.FORAGE, ToolUse.Use.CLEAR:
			return &"pick_bush"
		ToolUse.Use.WATER:
			return &"water_pour"
		ToolUse.Use.MOW:
			return &"scythe_swish"
		ToolUse.Use.DIG:
			return &"shovel_dig"
		ToolUse.Use.PLACE:
			return &"build_place"
		ToolUse.Use.TAKE_DOWN:
			return &"axe_chop"
		ToolUse.Use.GIVE_BONE:
			return &"dog_bark"
		ToolUse.Use.SADDLE, ToolUse.Use.UNSADDLE:
			return &"horse_whinny"

		ToolUse.Use.NEEDS_BETTER_TOOL, ToolUse.Use.NO_ROOM, ToolUse.Use.RIDING:
			return &"denied"
		ToolUse.Use.NOTHING:
			return &"scythe_swish" if held_tool == ItemTypes.SCYTHE else &""
	return &""


## The sound an animal of a kind (see WildlifeRules, and LivestockRules for the farm animals) makes
## now and then while it goes about its day; empty for those that are quiet.
static func animal_idle(kind: StringName) -> StringName:
	match kind:
		WildlifeRules.DEER:
			return &"deer_snort"
		WildlifeRules.RABBIT:
			return &"rabbit_rustle"
		WildlifeRules.SQUIRREL:
			return &"squirrel_chatter"
		WildlifeRules.GEESE, WildlifeRules.FLYING_GEESE:
			return &"goose_honk"
		LivestockRules.COW:
			return &"cow_moo"
		LivestockRules.SHEEP:
			return &"sheep_baa"
		LivestockRules.CHICKEN:
			return &"chicken_cluck"
		LivestockRules.DOG:
			return &"dog_bark"
		LivestockRules.CAT:
			return &"cat_meow"
		LivestockRules.HORSE:
			return &"horse_whinny"
	return &""


## The sound of an animal of a kind entering a state: starting to run from the player
## (Deer.BOUND, Rabbit.FLEE, Squirrel.FLEE, geese taking off) or a stork's clatter. Empty for any
## other.
static func animal_alarm(kind: StringName, state: StringName) -> StringName:
	match [kind, state]:
		[WildlifeRules.DEER, Deer.BOUND]:
			return &"deer_hooves"
		[WildlifeRules.RABBIT, Rabbit.FLEE]:
			return &"rabbit_rustle"
		[WildlifeRules.SQUIRREL, Squirrel.FLEE]:
			return &"squirrel_chatter"
		[WildlifeRules.GEESE, GroundFlock.FLY]:
			return &"goose_honk"
		[WildlifeRules.STORK, Stork.CLATTER], [WildlifeRules.ROOF_STORK, Stork.CLATTER]:
			return &"stork_clatter"
	return &""
