class_name ActionOutcome
extends RefCounted
## What one finished action of the player did, told once after it succeeded (GameState
## `action_done`): never for a refusal, and never for loading a save. The sounds listen to it, and
## the deed log of the gossip (design/villagers/gossip.md) will.
##
## `kind` is one of the constants below. `tile` is where it happened, on `map`; `object` the
## type of the object (a world object, a building or an animal kind) it was about, or empty; `items`
## (item id to count) what changed hands or lay down: what was planted, paid, picked up, made or
## given by the thing it was done to. Listeners only read an outcome: `items` is a dictionary that
## the action may have used for its own work, so a listener must not change it.

const TILL := &"till"
const PLANT := &"plant"
const HARVEST := &"harvest"
const FORAGE := &"forage"
const CLEAR := &"clear"
const WATER := &"water"
## The watering can filled at a well or at fresh water: `object` is the well, or empty for water.
const FILL_CAN := &"fill_can"
## Feed put into a hay rack: `object` is the rack and `items` the feed.
const FEED := &"feed"
const MOW := &"mow"
const DIG := &"dig"
## A hit that did not finish the object.
const HIT := &"hit"
## The hit that finished the object (a tree felled, a stone mined): `items` is what it dropped.
const BREAK := &"break"
const PLACE := &"place"
const TAKE_DOWN := &"take_down"
const BUILD := &"build"
const DEMOLISH := &"demolish"
const GIVE_BONE := &"give_bone"
const SADDLE := &"saddle"
const UNSADDLE := &"unsaddle"
## A recipe made at once, a slow one started at its station, and the done work taken out of it.
const CRAFT := &"craft"
const START_CRAFT := &"start_craft"
const TAKE_OUT := &"take_out"
const EAT := &"eat"
const DROP := &"drop"
const PICK_UP := &"pick_up"

## Who did it. Only the player so far.
const PLAYER := &"player"

var actor := PLAYER
var kind: StringName
var map: GameMap
var tile: Vector2i
var object: StringName
var items: Dictionary


func _init(
	kind_done: StringName, map_of: GameMap, tile_of: Vector2i, object_type := &"", items_of := {}
) -> void:
	kind = kind_done
	map = map_of
	tile = tile_of
	object = object_type
	items = items_of
