class_name GroundPickup
extends RefCounted
## The player and the items on the ground: the piles near them are pulled in and picked up as they
## walk, and a stack from the inventory is put down in front of them. Keeps nothing: every
## function is given the game, and tells it what was done (see GameState `report`).

## Items on the ground within this many tiles of the player (their feet) are pulled to them.
const PULL_RADIUS := 1.25
## How fast a pulled item moves, in tiles per second: faster than the player walks, so it
## catches up.
const PULL_SPEED := 8.0
## A pulled item that is this close is picked up.
const PICKUP_RADIUS := 0.15
## How far apart the points are that are looked at on the line between a pile and the player, in
## tiles: closer than a tile, so no tile the line crosses squarely is missed.
const PATH_SAMPLE_SPACING := 0.25


## Pulls the items on the ground near the player towards them and picks up those that
## arrive. What the inventory has no room for stays on the ground, and so do all piles of an
## item while it has no room at all. The piles are those of the map the player is on. Does nothing
## on horseback. Only the piles in the player's chunk and next to it are looked at: a pile out of
## reach has no business being settled or released here, and the player cannot get further than
## that in a frame.
static func collect(state: GameState, delta: float) -> void:
	var player := state.player
	var ground_items := state.current_map.ground_items
	var player_chunk := Chunk.world_to_chunk(player.tile())
	for ground_item in ground_items.in_chunks_around(player_chunk, 1):
		ground_item.settle_seconds = maxf(ground_item.settle_seconds - delta, 0.0)
		if ground_item.position.distance_to(player.position) > PULL_RADIUS:
			ground_item.is_dropped_by_player = false
	# On horseback nothing is picked up: only the inventory and eating are possible.
	if player.horse != null:
		return
	for ground_item in ground_items.near(player.position, PULL_RADIUS):
		if ground_item.settle_seconds > 0.0 or ground_item.is_dropped_by_player:
			continue
		if not player.inventory.can_add({ground_item.item: 1}, ground_item.state):
			continue
		var to_player := player.position - ground_item.position
		if not _is_path_open(state.current_map, ground_item.position, player.position):
			continue
		if to_player.length() > maxf(PICKUP_RADIUS, PULL_SPEED * delta):
			ground_items.move(
				ground_item, ground_item.position + to_player.normalized() * PULL_SPEED * delta
			)
			continue
		var picked_up := ground_item.count
		player.inventory.hold_notifications(
			func() -> void:
				ground_item.count = player.inventory.add(
					ground_item.item, ground_item.count, [], ground_item.state
				)
				if ground_item.count == 0:
					ground_items.remove(ground_item)
		)
		picked_up -= ground_item.count
		if picked_up > 0:
			state.report(
				ActionOutcome.PICK_UP,
				Vector2i(ground_item.position.floor()),
				&"",
				{ground_item.item: picked_up}
			)


## Whether nothing stops walking on the line between two positions: every tile it crosses but
## the two ends' own is walkable. A wall, a boulder or a stream between a pile and the player keeps
## the pile where it is. The line is about a tile long, so a few samples find the tiles on it.
static func _is_path_open(map: GameMap, from: Vector2, to: Vector2) -> bool:
	var from_tile := Vector2i(from.floor())
	var to_tile := Vector2i(to.floor())
	var samples := ceili(from.distance_to(to) / PATH_SAMPLE_SPACING)
	for sample in range(1, samples):
		var tile := Vector2i(from.lerp(to, float(sample) / samples).floor())
		if tile != from_tile and tile != to_tile and not map.is_walkable(tile):
			return false
	return true


## Puts the stack in inventory slot `slot` on the ground of the player's map in front of them, as
## drops lie (see `GameMap.drop_items`); the player picks it up again by walking away and back.
## Returns whether it did.
static func drop(state: GameState, slot: int) -> bool:
	var player := state.player
	if not player.inventory.has_slot(slot) or player.inventory.item_in(slot) == ItemTypes.NONE:
		return false
	var stack := player.inventory.slots[slot]
	var target := player.facing_tile()
	player.inventory.hold_notifications(
		func() -> void:
			player.inventory.destroy(slot)
			for pile in state.current_map.drop_items(
				target, {stack["item"]: stack["count"]}, stack.get("state", {})
			):
				pile.is_dropped_by_player = true
	)
	state.report(ActionOutcome.DROP, target, &"", {stack["item"]: stack["count"]})
	return true
