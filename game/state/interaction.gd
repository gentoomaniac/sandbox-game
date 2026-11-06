class_name Interaction
extends RefCounted
## What the player's E acts on: the villagers, beds, chests and crafting stations within reach of
## them (Targeting.REACH, the same as the use action's). Plain rules; Main asks and then chats,
## sleeps, opens the storage screen or opens the crafting menu of the station. A villager E speaks
## to (`npc_to_chat`) comes first, before any chest, station or bed.


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


## The chest or station E opens, or null. One on `target` (the targeted tile) wins; with a bed
## in reach the player sleeps instead, and without one the nearest chest or station in reach is
## opened.
static func object_to_open(state: GameState, target: Vector2i) -> WorldObject:
	var targeted := state.current_map.object_at(target)
	var offset := (target - state.player.tile()).abs()
	if targeted != null and _opens(targeted) and maxi(offset.x, offset.y) <= Targeting.REACH:
		return targeted
	if state.bed_in_reach() != null:
		return null
	return nearest_in_reach(state, _opens)


## Whether E opens the object: a chest, or a station (see StationRules).
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
		var offset := (npc.tile() - player_tile).abs()
		if maxi(offset.x, offset.y) > Targeting.REACH:
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
