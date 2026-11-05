class_name SoundEvents
extends RefCounted
## Which sound event a happening in the game makes: the footstep for the ground underfoot,
## the work sound of a tool hit or a use. Plain functions of what happened; the events are the
## ones in SoundRules.EVENTS. An empty name means the happening is silent.


## The step on a tile. Snow lies over anything, ice is frozen water, a floodplain is sand.
static func footstep(
	terrain: Tile.Terrain, is_frozen: bool, is_snowed: bool, is_indoors: bool
) -> StringName:
	if is_indoors or terrain == Tile.Terrain.FLOOR:
		return &"step_wood"
	if is_snowed:
		return &"step_snow"
	match terrain:
		Tile.Terrain.WATER:
			# Unfrozen water can't be walked on, so this is only a fallback.
			return &"step_ice" if is_frozen else &"step_grass"
		Tile.Terrain.WETLAND:
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
static func use(result: GameState.Use, held_tool: StringName) -> StringName:
	match result:
		GameState.Use.TILL:
			return &"hoe_till"
		GameState.Use.PLANT:
			return &"plant"
		GameState.Use.HARVEST, GameState.Use.FORAGE, GameState.Use.CLEAR:
			return &"pick_bush"
		GameState.Use.WATER:
			return &"water_pour"
		GameState.Use.MOW:
			return &"scythe_swish"
		GameState.Use.DIG:
			return &"shovel_dig"
		GameState.Use.NEEDS_BETTER_TOOL:
			return &"denied"
		GameState.Use.NOTHING:
			return &"scythe_swish" if held_tool == ItemTypes.SCYTHE else &""
	return &""
