class_name DebugHarvest
extends RefCounted
## For screenshots of the harvest animations (`--harvest=<x>,<y>`): in a row from that
## tile, six tiles apart, the player fells an oak from the left, fells one from the right, cuts
## a trunk into logs, breaks a stone and mows a patch of tall grass (use `--day=45`, tall grass
## is gone in winter). It uses the real hits, so the view sees what it sees in play: take the
## screenshot a fraction of a second later (`--screenshot-delay`). Needs the world drawn.

const SPACING := 6
## The tiles cleared around each spot, from its own.
const CLEARED := Rect2i(-2, -1, 5, 4)
const MOWN_GRASS_OFFSETS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(-1, 1), Vector2i(1, 1)
]


static func run(state: GameState, origin: Vector2i) -> void:
	var world := state.world
	var spots: Array[Vector2i] = []
	for index in 5:
		var spot := origin + Vector2i(index * SPACING, 0)
		spots.append(spot)
		for y in CLEARED.size.y:
			for x in CLEARED.size.x:
				var tile := spot + CLEARED.position + Vector2i(x, y)
				world.remove_object(tile)
				world.set_terrain(tile, Tile.Terrain.GRASS)
	state.player.energy = 100.0
	for index in 2:
		world.add_object(WorldObject.new(WorldObjectTypes.OAK, spots[index]))
	var trunk_tree := WorldObject.new(WorldObjectTypes.OAK, spots[2])
	TrunkPlacement.lay(world, trunk_tree, spots[2] + Vector2i.LEFT)
	world.add_object(WorldObject.new(WorldObjectTypes.STONE, spots[3]))
	for offset in MOWN_GRASS_OFFSETS:
		world.add_object(WorldObject.new(WorldObjectTypes.TALL_GRASS, spots[4] + offset))

	_swing(state, spots[0], Vector2i.LEFT, ItemTypes.RUSTY_IRON_AXE)
	_swing(state, spots[1], Vector2i.RIGHT, ItemTypes.RUSTY_IRON_AXE)
	_swing(state, spots[2] + Vector2i.RIGHT, Vector2i.LEFT, ItemTypes.RUSTY_IRON_AXE)
	_swing(state, spots[3], Vector2i.LEFT, ItemTypes.RUSTY_IRON_PICKAXE)
	_mow(state, spots[4])
	state.player.position = Vector2(spots[2] + Vector2i(0, 3)) + Vector2(0.5, 0.5)


## The player stands `from_side` of `tile` and hits what is there once, the hit that finishes it
## (the earlier hits are taken off quietly, so only that hit's effects show).
static func _swing(state: GameState, tile: Vector2i, from_side: Vector2i, tool: StringName) -> void:
	state.player.position = Vector2(tile + from_side) + Vector2(0.5, 0.5)
	_hold(state, tool)
	var object := state.world.object_at(tile)
	var power := ItemTypes.tool_power(tool)
	while not object.is_finished_by(power):
		object.take_hit(power)
	state.use_tile(tile)


static func _mow(state: GameState, spot: Vector2i) -> void:
	state.player.position = Vector2(spot) + Vector2(0.5, 0.5)
	state.player.facing = Vector2i.DOWN
	_hold(state, ItemTypes.RUSTY_IRON_SCYTHE)
	state.use_facing_tile()


static func _hold(state: GameState, item: StringName) -> void:
	var inventory := state.player.inventory
	if inventory.item_in(inventory.selected_slot) == item:
		return
	inventory.add(item, 1)
	for slot in Inventory.SLOT_COUNT:
		if inventory.item_in(slot) == item:
			inventory.move_to(slot, inventory, inventory.selected_slot)
			return
