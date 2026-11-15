class_name NpcSkip
extends RefCounted
## One villager's trip through a time skip (see NpcTravel `advance_skip`): how far it may still
## walk, when it began, and what it waits for or has pinned. The trip is over when `advance_skip`
## says so; a mask that is not made yet makes it stop and be called again, so that waiting for the
## worker is the caller's, in one go or over frames.
##
## How it all works: design/tech/pathfinding.md.

var npc: Npc
## The tiles it may still walk, and the game minute (`GameClock.total_minutes`) the skip began at.
var tiles_left: float
var start_minute: int
## How far along its path it has walked in the skip, in tiles, for the time it enters a tile at.
var tiles_walked := 0.0
## The chunk whose masks were last asked for ahead, and the masks pinned since.
var asked_ahead_from: Variant
var pinned: Dictionary[Vector2i, bool] = {}
## The chunk whose mask `advance_skip` waits for when it says false.
var missing_mask: Vector2i


func _init(walker: Npc, tiles: float, minute: int) -> void:
	npc = walker
	tiles_left = tiles
	start_minute = minute
