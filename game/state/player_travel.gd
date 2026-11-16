class_name PlayerTravel
extends RefCounted
## How the player gets about: walking at the speed the player's state and the ground allow, riding
## a saddled horse (its trot, its sprint and the stamina that pays for it), getting on and off, and
## standing again on free ground. It keeps nothing: every function is given the game, and the
## riding state is the player's (see PlayerState `moving_seconds`).

## Getting off a horse puts the player on free ground at most this many tiles from it.
const DISMOUNT_REACH := 2


## How fast the player walks, as a fraction of full speed: the slowest of what low energy and
## a debuff allow, and mud, or wading in flooded tidal mud, slows on top of that, while a way
## (a plank walk, a stone path) speeds it up. On horseback it is the horse's pace, which nothing
## slows.
static func walk_speed_factor(state: GameState) -> float:
	var player := state.player
	if player.horse != null:
		var pace := "ride_walk_factor"
		if is_sprinting(state):
			pace = "ride_sprint_factor"
		elif is_trotting(state):
			pace = "ride_trot_factor"
		return state.livestock.rules.general(pace)
	var factor := state.energy_rules.walk_factor(player.energy)
	if player.is_debuffed:
		factor = minf(factor, state.energy_rules.debuff_walk_factor())
	if not state.is_inside():
		var tile := player.tile()
		var path_rules := PathRules.default_rules()
		# A way is walked dry-shod over mud and the flats. Worn ground is never tidal mud, so
		# only one of the other two can apply.
		if state.world.is_way_at(tile):
			factor *= path_rules.way_walk_factor()
		elif state.world.is_muddy_at(tile):
			factor *= path_rules.walk_factor()
		elif state.world.is_flooded(tile):
			factor *= path_rules.wading_walk_factor()
	return factor


## Walks the player on the map they are on (see PlayerState.move), or rides the horse they are on.
## Outdoors, each tile they step onto wears a little towards a desire path.
static func walk(state: GameState, direction: Vector2, delta: float, speed_factor := 1.0) -> void:
	var player := state.player
	var tile_before := player.tile()
	var position_before := player.position
	if player.horse != null:
		_tire_or_rest_horse(state, direction != Vector2.ZERO, delta)
	player.move(state.current_map, direction, delta, speed_factor, state.cheats.is_noclip)
	if not state.is_inside():
		state.explored.see(player.tile())
		state.harm.check_pushing(player.position)
	player.moving_seconds = player.moving_seconds + delta if direction != Vector2.ZERO else 0.0
	# A noclip walk (through trees, rocks and walls) leaves no path.
	if not state.is_inside() and not state.cheats.is_noclip and player.tile() != tile_before:
		state.world.wear_tile(player.tile())
	# A horse's hooves, not the rider's boots, would leave the prints (see Footprints).
	if not state.is_inside() and not state.cheats.is_noclip and player.horse == null:
		state.world.footprints.walk(state.world, player.stride, position_before, player.position)


## Puts a player who stands where they don't fit (noclip just turned off in a lake, a rock or a
## house's walls) on the middle of the nearest tile, within `reach` tiles, where they fit and no
## part of them is on a building (its door would take them inside), with the horse they ride. One
## lying in a bed stays: they get out of it as they move. Returns whether they now fit.
static func put_player_on_free_ground(state: GameState, reach := 12) -> bool:
	var player := state.player
	if (
		player.bed_lying_in != null
		or PlayerState.can_stand_at(state.current_map, player.position, player.horse == null)
	):
		return true
	var here := player.tile()
	var nearest := Vector2.INF
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var centre := Vector2(here + Vector2i(x, y)) + Vector2(0.5, 0.5)
			var is_nearer := (
				centre.distance_to(player.position) < nearest.distance_to(player.position)
			)
			if is_nearer and _is_free_ground_for_player(state, centre):
				nearest = centre
	if nearest == Vector2.INF:
		return false
	player.position = nearest
	if player.horse != null:
		player.horse.position = nearest
	return true


## Whether the player rides fast enough for the horse to trot (see data/livestock.cfg).
static func is_trotting(state: GameState) -> bool:
	return (
		state.player.horse != null
		and state.player.moving_seconds >= state.livestock.rules.general("trot_after_seconds")
	)


## Whether the player sprints: the key is held on a horse that is trotting and has stamina.
static func is_sprinting(state: GameState) -> bool:
	return state.player.is_sprint_held and not state.player.is_horse_winded and is_trotting(state)


## Gets on a saddled horse: the player sits on it where it stands, facing its way, and it goes where
## they ride until they get off (see `dismount`).
static func mount(state: GameState, horse: FarmAnimal) -> void:
	var player := state.player
	assert(horse.is_saddled and player.horse == null, "Not a horse to get on")
	player.horse = horse
	horse.is_ridden = true
	player.bed_lying_in = null
	player.position = horse.position
	player.facing = Vector2i.RIGHT if horse.facing > 0.0 else Vector2i.LEFT
	state.player.moving_seconds = 0.0
	state.player.is_horse_winded = horse.stamina == 0.0


## Gets off the horse onto free ground beside it (see `dismount_spot`); the horse stays where it is
## and goes about its day again. Returns false, and the player stays on, if there is no room.
static func dismount(state: GameState) -> bool:
	var spot := dismount_spot(state)
	if spot == Vector2.INF:
		return false
	state.player.position = spot
	leave_horse(state)
	return true


## The horse stays where it is, and the player is no longer on it (wherever they are put next).
static func leave_horse(state: GameState) -> void:
	var player := state.player
	if player.horse == null:
		return
	player.horse.is_ridden = false
	state.livestock.stand_still(player.horse)
	player.horse = null


## Where getting off the horse puts the player: the middle of a tile near it, within
## DISMOUNT_REACH, where they stand free (never in the water, a wall or a building). Not on the
## horse's own tile, and best at its side: a tile along its length (to the left or right, as it
## is drawn standing) counts a tile further off. Vector2.INF if there is none.
static func dismount_spot(state: GameState) -> Vector2:
	var here := state.player.tile()
	var nearest := Vector2.INF
	var nearest_cost := INF
	for y in range(DISMOUNT_REACH, -DISMOUNT_REACH - 1, -1):
		for x in range(-DISMOUNT_REACH, DISMOUNT_REACH + 1):
			var centre := Vector2(here + Vector2i(x, y)) + Vector2(0.5, 0.5)
			var cost := centre.distance_to(state.player.position) + absi(x)
			var is_cheaper := cost < nearest_cost and Vector2i(x, y) != Vector2i.ZERO
			if is_cheaper and _is_free_ground_for_player(state, centre):
				nearest = centre
				nearest_cost = cost
	return nearest


static func _is_free_ground_for_player(state: GameState, feet: Vector2) -> bool:
	return (
		PlayerState.can_stand_at(state.current_map, feet)
		and not PlayerState.touches_building(state.current_map, feet)
	)


## A sprint uses up the ridden horse's stamina; any other pace gives some back, a walk slower than
## standing still. A horse that used it up is winded until a part of it has come back.
static func _tire_or_rest_horse(state: GameState, is_moving: bool, delta: float) -> void:
	var rules := state.livestock.rules
	var horse := state.player.horse
	if is_sprinting(state):
		horse.stamina = maxf(0.0, horse.stamina - delta / rules.general("sprint_stamina_seconds"))
		state.player.is_horse_winded = horse.stamina == 0.0
		return
	var regain_key := "stamina_walk_regain_seconds" if is_moving else "stamina_stand_regain_seconds"
	horse.stamina = minf(1.0, horse.stamina + delta / rules.general(regain_key))
	if horse.stamina >= rules.general("sprint_again_stamina"):
		state.player.is_horse_winded = false
