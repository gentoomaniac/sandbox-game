class_name Crowing
extends RefCounted
## When a rooster crows (task 204; the numbers are `[rooster]` in data/livestock.cfg): a run of
## crows at dawn, once a day, and now and then a run by day. Livestock asks only for a rooster that
## is awake and out of the coop, so none crows at night.


## Lets `delta` seconds pass for an awake rooster at the time of `clock`, `sunrise` being that of
## its day (game minutes); returns whether it crows now.
static func update(
	rooster: FarmAnimal,
	delta: float,
	clock: GameClock,
	sunrise: float,
	rules: LivestockRules,
	rng: RandomNumberGenerator
) -> bool:
	rooster.crow_wait_seconds = maxf(0.0, rooster.crow_wait_seconds - delta)
	if rooster.crows_left == 0:
		var is_dawn := clock.minute_of_day - sunrise < rules.rooster("dawn_minutes")
		if is_dawn and rooster.last_dawn_crow_day != clock.day:
			rooster.last_dawn_crow_day = clock.day
			rooster.crows_left = rules.pick_rooster_count("dawn_crows", rng)
		elif rng.randf() < rules.rooster("day_crow_chance") * delta:
			rooster.crows_left = rules.pick_rooster_count("day_crows", rng)
		else:
			return false
	if rooster.crow_wait_seconds > 0.0:
		return false
	rooster.crows_left -= 1
	rooster.crow_wait_seconds = rules.pick_rooster_seconds("crow_gap_seconds", rng)
	return true
