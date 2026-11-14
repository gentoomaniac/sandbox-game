class_name Interaction
extends RefCounted
## What the player's E acts on: the villagers, saddled horses, beds, chests and crafting stations
## within reach of them (Targeting.REACH, the same as the use action's). Plain rules; Main asks and
## then chats, gets on the horse, sleeps, opens the storage screen or opens the crafting menu of
## the station. A villager E speaks to (`npc_to_chat`) comes first, then a horse to get on
## (`horse_to_mount`), before any chest, station or bed; a bell frame to ring (`bell_frame_to_ring`)
## comes after the chests and stations.

## What E does, and for whom (see `choice_at`).
enum Kind {
	NOTHING,
	DISMOUNT,
	CHAT,
	MOUNT,
	OPEN_STATION_GRID,
	OPEN_CHEST,
	OPEN_FIRE,
	OPEN_CRAFTING,
	RING_BELL,
	SLEEP,
}


## What E does: its `kind`, and the `subject` it does it to: the Npc spoken to, the FarmAnimal got
## on, the WorldObject opened, the Building whose bell rings, the WorldObject bed slept in; null
## for the rest.
class Choice:
	var kind: Kind
	var subject: Variant

	func _init(choice_kind: Kind, choice_subject: Variant = null) -> void:
		kind = choice_kind
		subject = choice_subject


## What E does with the player facing or pointing at `target`: on horseback it gets off, else the
## first of these that applies, in order: speak to a villager, get on a saddled horse, open a chest
## or station, ring a bell frame, sleep in a bed. The one place that decides it: Main does what it
## says and the action hint shows it.
static func choice_at(state: GameState, target: Vector2i) -> Choice:
	if state.player.horse != null:
		return Choice.new(Kind.DISMOUNT)
	var npc := npc_to_chat(state, target)
	if npc != null:
		return Choice.new(Kind.CHAT, npc)
	var horse := horse_to_mount(state, target)
	if horse != null:
		return Choice.new(Kind.MOUNT, horse)
	var object := object_to_open(state, target)
	if object != null:
		if StationRules.default_rules().grid_slots_of(object.type) > 0:
			return Choice.new(Kind.OPEN_STATION_GRID, object)
		if Campfire.is_campfire(object):
			return Choice.new(Kind.OPEN_FIRE, object)
		return Choice.new(Kind.OPEN_CHEST if object.storage != null else Kind.OPEN_CRAFTING, object)
	var frame := bell_frame_to_ring(state)
	if frame != null:
		return Choice.new(Kind.RING_BELL, frame)
	var bed := state.bed_in_reach()
	return Choice.new(Kind.SLEEP, bed) if bed != null else Choice.new(Kind.NOTHING)


## The nearest object on the player's map within reach that `is_wanted` says yes to, or null.
static func nearest_in_reach(state: GameState, is_wanted: Callable) -> WorldObject:
	var player_tile := state.player.tile()
	var nearest: WorldObject = null
	for y in range(-Targeting.REACH, Targeting.REACH + 1):
		for x in range(-Targeting.REACH, Targeting.REACH + 1):
			var object := state.current_map.object_at(player_tile + Vector2i(x, y))
			if object == null or not is_wanted.call(object):
				continue
			if nearest == null or _distance(state, object) < _distance(state, nearest):
				nearest = object
	return nearest


## The bell frame a click on `clicked` or E rings, or null: outdoors on foot, one with a tile of its
## footprint in reach (within Targeting.REACH of the player's tile) and, for a click, with the
## clicked tile in its footprint. E passes no tile and leaves it to a bed in reach (to sleep in); a
## click leaves it to the held item when that has a use on the tile.
static func bell_frame_to_ring(state: GameState, clicked: Variant = null) -> Building:
	if state.is_inside() or state.player.horse != null:
		return null
	if clicked == null and state.bed_in_reach() != null:
		return null
	if clicked != null and state.use_at(clicked) != ToolUse.Use.NOTHING:
		return null
	var player_tile := state.player.tile()
	for y in range(-Targeting.REACH, Targeting.REACH + 1):
		for x in range(-Targeting.REACH, Targeting.REACH + 1):
			var building := state.world.building_at(player_tile + Vector2i(x, y))
			if (
				building != null
				and building.type == BuildingTypes.BELL_FRAME
				and (clicked == null or building.tiles().has(clicked))
			):
				return building
	return null


## The chest or station E opens, or null. One on `target` (the targeted tile) wins; with a bed
## in reach the player sleeps instead, and without one the nearest chest or station in reach is
## opened.
static func object_to_open(state: GameState, target: Vector2i) -> WorldObject:
	var targeted := state.current_map.object_at(target)
	if (
		targeted != null
		and _opens(targeted)
		and Targeting.is_tile_in_reach(state.player.tile(), target)
	):
		return targeted
	if state.bed_in_reach() != null:
		return null
	return nearest_in_reach(state, _opens)


## Whether E opens the object: a chest, a campfire or a station (see StationRules).
static func _opens(object: WorldObject) -> bool:
	return object.storage != null or StationRules.default_rules().station_of(object.type) != &""


static func _distance(state: GameState, object: WorldObject) -> float:
	return (Vector2(object.pos) + Vector2(0.5, 0.5)).distance_to(state.player.position)


## The villager E speaks to, or null: the one on the targeted tile if that is in reach, else the
## nearest one in reach in front of the player (villagers move, so the player need not face their
## very tile; one behind them would take E from the chest they face). None indoors, where there
## are none.
static func npc_to_chat(state: GameState, target: Vector2i) -> Npc:
	if state.is_inside():
		return null
	var player_tile := state.player.tile()
	var facing := Vector2(state.player.facing)
	var nearest: Npc = null
	for npc in state.npcs.all():
		if not Targeting.is_tile_in_reach(player_tile, npc.tile()):
			continue
		if npc.tile() == target:
			return npc
		var to_npc := npc.position - state.player.position
		var is_nearer := (
			nearest == null or to_npc.length() < nearest.position.distance_to(state.player.position)
		)
		if to_npc.dot(facing) > 0.0 and is_nearer:
			nearest = npc
	return nearest


## The saddled horse E gets on, or null: the one nearest the middle of the targeted tile, within
## ToolUse.ANIMAL_REACH of it, if that tile is in reach. None indoors, where there are none.
static func horse_to_mount(state: GameState, target: Vector2i) -> FarmAnimal:
	if state.is_inside() or not Targeting.is_tile_in_reach(state.player.tile(), target):
		return null
	var horse := state.livestock.nearest(
		LivestockRules.HORSE, Vector2(target) + Vector2(0.5, 0.5), ToolUse.ANIMAL_REACH
	)
	return horse if horse != null and horse.is_saddled else null
