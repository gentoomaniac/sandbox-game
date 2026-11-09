class_name Targeting
extends RefCounted
## Which tile the player's use action aims at: the one under the mouse while the mouse is in
## use, otherwise the one the player faces. Pure rule; the scenes feed it positions.

enum Source { MOUSE, FACING }

## How far (in tiles, diagonals included) from the player's tile the use action reaches:
## the 3x3 tiles around them. Tools may reach further later.
const REACH := 1

var tile := Vector2i.ZERO
var source := Source.FACING
var is_in_reach := true


## `is_mouse_active` is false once the mouse has been idle for a while. The facing tile is
## always in reach.
static func resolve(
	player_tile: Vector2i, facing_tile: Vector2i, mouse_tile: Vector2i, is_mouse_active: bool
) -> Targeting:
	var targeting := Targeting.new()
	if not is_mouse_active:
		targeting.tile = facing_tile
		return targeting
	targeting.tile = mouse_tile
	targeting.source = Source.MOUSE
	targeting.is_in_reach = is_tile_in_reach(player_tile, mouse_tile)
	return targeting


## Whether `tile` is within REACH of the player's tile: the 3x3 tiles around them.
static func is_tile_in_reach(player_tile: Vector2i, tile: Vector2i) -> bool:
	var offset := (tile - player_tile).abs()
	return maxi(offset.x, offset.y) <= REACH
