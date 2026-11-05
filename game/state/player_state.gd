class_name PlayerState
extends RefCounted
## The player: where they stand and which bed is home. This is the source of truth for the
## player's position; PlayerView only draws it, and `move` is the only thing that walks.

const SPEED := 5.0  # tiles per second
## The player's body, as the area they occupy on the ground: this wide and this tall,
## measured up from the feet. Smaller than a tile, so they can pass between trees.
const BODY_HALF_WIDTH := 0.3
const BODY_HEIGHT := 0.3
## A long frame is walked in steps of at most this long, so the player cannot jump through
## a thin wall.
const MAX_STEP_SECONDS := 0.05

## World position of the feet, in tiles: tile (x, y) spans x..x+1 and y..y+1.
var position := Vector2.ZERO
## The axis direction the player last tried to walk in (UP, DOWN, LEFT or RIGHT), also when
## a wall stopped them.
var facing := Vector2i.DOWN
## The bed the player last slept in, where they wake up when they pass out: its tile on
## `home_map` (the world, or the inside of a building).
var home_map: GameMap
var home_bed := Vector2i.ZERO

## What they carry; the selected hotbar slot is what they hold.
var inventory := Inventory.new()

# --- Looks ---
## What the character wears and holds.
var appearance := Appearance.new()


## The tile the player's feet are on.
func tile() -> Vector2i:
	return Vector2i(position.floor())


## The tile in front of the player: the target of their actions.
func facing_tile() -> Vector2i:
	return tile() + facing


## Walks along `direction` for `delta` seconds. Each axis moves on its own, so the player
## slides along a wall instead of stopping against it.
func move(map: GameMap, direction: Vector2, delta: float) -> void:
	if direction != Vector2.ZERO:
		# The axis the player moves along most; a tie faces vertically.
		if absf(direction.x) > absf(direction.y):
			facing = Vector2i.RIGHT if direction.x > 0 else Vector2i.LEFT
		else:
			facing = Vector2i.DOWN if direction.y > 0 else Vector2i.UP
	var velocity := direction.limit_length(1.0) * SPEED
	while delta > 0.0:
		var step := velocity * minf(delta, MAX_STEP_SECONDS)
		delta -= MAX_STEP_SECONDS
		for axis in [Vector2(step.x, 0.0), Vector2(0.0, step.y)]:
			if can_stand_at(map, position + axis):
				position += axis


## The home map is not saved here: a map is saved as a reference into the world (see
## GameState.to_dict), so GameState writes and restores it.
func to_dict() -> Dictionary:
	return {
		"position": SaveCodec.float_vector_to_json(position),
		"facing": SaveCodec.vector_to_json(facing),
		"home_bed": SaveCodec.vector_to_json(home_bed),
		"appearance": appearance.to_dict(),
		"inventory": inventory.to_dict(),
	}


## `home_map` is the map the saved `home_bed` is on.
static func from_dict(data: Dictionary, home_map: GameMap) -> PlayerState:
	var player := PlayerState.new()
	player.position = SaveCodec.float_vector_from_json(data["position"])
	player.facing = SaveCodec.vector_from_json(data["facing"])
	player.home_map = home_map
	player.home_bed = SaveCodec.vector_from_json(data["home_bed"])
	player.appearance = Appearance.from_dict(data["appearance"])
	player.inventory = Inventory.from_dict(data["inventory"])
	return player


## Whether a player with their feet at `feet` fits: every tile their body touches is walkable.
static func can_stand_at(map: GameMap, feet: Vector2) -> bool:
	var top_left := Vector2i(Vector2(feet.x - BODY_HALF_WIDTH, feet.y - BODY_HEIGHT).floor())
	# Ceiling minus one: a body that ends exactly on a tile edge does not touch the next tile.
	var bottom_right := Vector2i(int(ceilf(feet.x + BODY_HALF_WIDTH)) - 1, int(ceilf(feet.y)) - 1)
	for y in range(top_left.y, bottom_right.y + 1):
		for x in range(top_left.x, bottom_right.x + 1):
			if not map.is_walkable(Vector2i(x, y)):
				return false
	return true
