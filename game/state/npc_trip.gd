class_name NpcTrip
extends RefCounted
## What one villager knows of its walk to a place: where, over what map, the way found and how far
## along it they are, and what is being waited for. NpcTravel does the walking; the trip is only its
## state, and it ends when the villager arrives or is sent elsewhere (`Npc.trip` is null again).

## SEARCHING: it stands while a way is looked for. WALKING: along `path`. WAITING: for the player to
## move off or to finish talking, which is not being stuck. BLOCKED: no way was found, it stands and
## looks again when the world has changed.
enum State { SEARCHING, WALKING, WAITING, BLOCKED }
## Why a trip is blocked (see `Npcs.trip_blocked`): there is no way to the goal, or the villager
## cannot get on along the one found.
enum Block { NO_WAY, NOT_LOADED, STUCK }

## The map the villager walks on, and the tile they walk to on it.
var map: GameMap
var goal: Vector2i
var state := State.SEARCHING

## The search that is looking for a way (see Pathfinder), until it is done.
var search: PathSearch
## The tiles to walk, and how many of them are reached. A way that ends short of the goal is a leg
## (`is_leg`): at its end a new search starts.
var path: Array[Vector2i] = []
var next_index := 0
var is_leg := false
## How many legs in a row this chain of searches has walked (see `max_legs`).
var legs := 0
## How many searches the trip has made in all, and how many tiles they have looked at (the
## finished ones; see `NpcTravel.text_of`).
var searches := 0
var nodes_looked_at := 0
## How many times in a row they looked for another way after being stuck, and for how long they
## have been stuck, which is the time without a free step, not the time waiting for the player.
var retries := 0
var stuck_seconds := 0.0
## How long a talk with the player still holds them.
var pause_seconds := 0.0
## How long since the last search began, and what the map's `change_count` was then.
var seconds_since_search := 0.0
var change_count_at_search := 0
## Why the trip is blocked, while it is.
var block_reason := Block.NO_WAY
## Whether the villager's routine has been told of the block (once, however often it looks again).
var is_blocked_told := false


## What a block is called, for the console and the F3 line.
static func block_text(reason: Block) -> String:
	match reason:
		Block.NOT_LOADED:
			return "not loaded"
		Block.STUCK:
			return "stuck"
	return "no way"


func _init(walk_map: GameMap, goal_tile: Vector2i) -> void:
	map = walk_map
	goal = goal_tile
