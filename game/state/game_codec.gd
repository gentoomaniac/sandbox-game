class_name GameCodec
extends RefCounted
## A GameState as save data and back (the game part of a save file: see SaveFile for the envelope,
## the version and the file, SaveMigrations for older versions and the checks of
## game/state/save_checks for what a loaded game must satisfy before `from_dict` reads it). The
## keys on disk are the ones named here and nowhere else. Keeps nothing.
##
## Maps are saved as references, never as copies: `{"kind": "world"}`, or
## `{"kind": "interior", "building": [x, y]}` for the interior of the building with that
## origin. So the current map and the home map stay the very objects they point at.


static func to_dict(state: GameState) -> Dictionary:
	return dict_of(snapshot(state))


## A copy of what `to_dict` writes that is quick to take and shares nothing with the game, and
## that `dict_of` makes save data of: the part of saving that has to stop the game, a moment.
static func snapshot(state: GameState) -> Dictionary:
	var player := state.player
	state.livestock.account_clock(state.clock)
	var player_data := player.to_dict()
	# A game saved on horseback loads with the player standing beside the horse (or, with no room
	# there, on its spot).
	var spot := Vector2.INF if player.horse == null else state.travel.dismount_spot(state)
	if spot != Vector2.INF:
		player_data["position"] = SaveCodec.float_vector_to_json(spot)
	return {
		"world": state.world.snapshot(),
		"explored": state.explored.snapshot(),
		"clock": state.clock.to_dict(),
		"player": player_data,
		"livestock": state.livestock.to_array(),
		"npcs": state.npcs.to_array(),
		"shops": state.shops.to_dict(),
		"quests": state.quests.to_dict(),
		"deeds": state.deeds.to_array(),
		"current_map": _map_to_ref(state, state.current_map),
		"home_map": _map_to_ref(state, player.home_map),
	}


## The save data of a `snapshot`. Safe to call from a thread.
static func dict_of(snapshot_data: Dictionary) -> Dictionary:
	var data := snapshot_data.duplicate()
	data["world"] = WorldSave.dict_of(snapshot_data["world"])
	data["explored"] = Exploration.array_of(snapshot_data["explored"])
	return data


## The chunks of the restored world are not loaded yet: whoever shows it streams them in.
static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new(GameClock.from_dict(data["clock"]))
	GameFactory.attach_world(state, World.from_dict(data["world"], state.clock))
	state.player = PlayerState.from_dict(data["player"], _map_from_ref(state, data["home_map"]))
	state.explored.load_array(data["explored"])
	state.livestock.load_array(data["livestock"])
	state.npcs.load_array(data["npcs"], state.world)
	for npc in state.npcs.all():
		state.activities.resume(npc)
	state.shops.load_dict(data["shops"])
	state.quests.load_dict(data["quests"])
	state.deeds.load_array(data["deeds"])
	state.building_inside = _building_of_ref(state, data["current_map"])
	# The land about the player is seen from where they stand (a save from before the record has
	# none).
	if not state.is_inside():
		state.explored.see(state.player.tile())
	# No sleep wakes between 01:00 and 06:30, so a game saved then was quit by a player who
	# stayed up: they still pass out (`is_up_too_late` itself is not saved).
	var minute := state.clock.minute_of_day
	state.is_up_too_late = (
		minute >= PlayerRest.LATE_NIGHT_MINUTE and minute < PlayerRest.WAKE_UP_MINUTE
	)
	# The rain of the hours before the save still lies on the ground.
	state.refresh_mud()
	return state


static func _map_to_ref(state: GameState, map: GameMap) -> Dictionary:
	if map == state.world:
		return {"kind": "world"}
	var building := state.building_with_interior(map)
	assert(building != null, "A map that belongs to no building")
	return {"kind": "interior", "building": SaveCodec.vector_to_json(building.origin)}


static func _map_from_ref(state: GameState, ref: Dictionary) -> GameMap:
	var building := _building_of_ref(state, ref)
	return state.world if building == null else building.interior


## The building whose interior the reference names, or null for the world.
static func _building_of_ref(state: GameState, ref: Dictionary) -> Building:
	if ref["kind"] == "world":
		return null
	var origin := SaveCodec.vector_from_json(ref["building"])
	for building in state.world.buildings():
		if building.origin == origin:
			return building
	assert(false, "No building at %s" % origin)
	return null
