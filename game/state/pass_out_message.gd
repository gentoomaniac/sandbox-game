class_name PassOutMessage
extends RefCounted
## The message on the black screen after passing out: what happened, how long the player slept,
## where they wake and what the debuff does, e.g. "You collapsed from exhaustion. You slept 10
## hours and wake at the camp, still worn out: slow, weak and with half your energy until
## midnight."


## The message for a player who has just passed out (see GameState `pass_out`) after
## `minutes_slept`, from staying up too late or else from exhaustion.
static func text(state: GameState, was_up_too_late: bool, minutes_slept: int) -> String:
	var what_happened := (
		"You stayed up far too late and collapsed."
		if was_up_too_late
		else "You collapsed from exhaustion."
	)
	var hours := roundi(minutes_slept / float(GameClock.MINUTES_PER_HOUR))
	var where := "at the camp" if state.player.home_map == state.world else "at home"
	var energy_share := state.energy_rules.debuff_energy_max() / PlayerState.MAX_ENERGY
	var energy := (
		"half your energy"
		if is_equal_approx(energy_share, 0.5)
		else "%d %% of your energy" % roundi(energy_share * 100.0)
	)
	return (
		"%s You slept %d hours and wake %s, still worn out: slow, weak and with %s until midnight."
		% [what_happened, hours, where, energy]
	)
