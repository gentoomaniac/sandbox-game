extends CoopCase
## The characterization of Livestock: a pen with a coop, a trough and a herd of every sort of animal
## (a dog following the player, a cat with a mouse in sight, a rooster, hens), played for hours
## with the same dice, live (frame by frame) and skipped. What each animal ends as is a digest
## that is pinned, so that moving the code of its motion, needs, roosting and following about
## changes no outcome. When a change of the rules is meant to change one, the digest is the new
## one to pin, with the reason in the commit.

const LIVE_HOURS := 26
## How often the live run is looked at: it has to be seen asleep, in the coop and out again.
const LIVE_LOOK_EVERY_HOURS := 2
const LIVE_DIGEST := "e8a02d87d4c0bf85777dff9fbd39cacb643e25a7e3370ee734b0b2c96416c80d"
const LONG_SKIP_DIGEST := "72ce85adc88f974588cdcd8fa082abaf861ab7302568537f057f15fb2b45e448"
const SKIP_TO_MIDNIGHT_DIGEST := "4f055a10c94b7e9ffcedd240298f9d3ad1f176fcb2ffc220857f2aae7331c21a"
const SHORT_SKIP_DIGEST := "28b738684f421af6ab9bd447c3b5d41eb43ff6ee89f2ea3b0ee7804d5b6638d1"
## The game minutes of one pass of the live loop, in steps of STEP_SECONDS.
const STEPS_PER_MINUTE := 13


func before_each() -> void:
	super()
	_state.cheats.are_needs_off = false
	_state.player.position = _pen_middle() + Vector2(2.5, 2.5)
	var trough := WorldObject.new(WorldObjectTypes.TROUGH, _middle + Vector2i(-1, -1))
	_world.add_object(trough)
	ObjectStock.add(trough, 100)
	var herd := {
		LivestockRules.COW: [Vector2(-2.0, 1.0), Vector2(1.0, -1.0)],
		LivestockRules.PIG: [Vector2(2.0, -1.0)],
		LivestockRules.SHEEP: [Vector2(-1.0, 2.5)],
		LivestockRules.RABBIT: [Vector2(0.5, 2.0)],
		LivestockRules.CAT: [Vector2(-2.0, -1.0)],
		LivestockRules.DOG: [Vector2(1.0, 1.0)],
	}
	for species: StringName in herd:
		for offset: Vector2 in herd[species]:
			var animal := FarmAnimal.new(
				species, _livestock.rules.looks(species)[0], _pen_middle() + offset
			)
			_livestock.add(animal)
			_livestock.stand_still(animal)
	_hens(3)
	var rooster := FarmAnimal.new(
		LivestockRules.CHICKEN, LivestockRules.ROOSTER_LOOK, _pen_middle() + Vector2(1.5, 2.5)
	)
	_livestock.add(rooster)
	_livestock.stand_still(rooster)
	var prey := Prey.new()
	prey.position = _pen_middle() + Vector2(1.0, -1.0)
	_livestock.add_prey(prey)
	_state.clock.day = DAY
	_state.clock.minute_of_day = NOON
	_livestock.account_clock(_state.clock)
	_livestock.start_following(
		_livestock.nearest(LivestockRules.DOG, _pen_middle(), 9.0), _state.clock.total_minutes()
	)


## What the herd looked like each `LIVE_LOOK_EVERY_HOURS` of `hours` of play.
func _live_digests(hours: int) -> String:
	var digests := ""
	for hour in hours:
		for _minute in GameClock.MINUTES_PER_HOUR:
			for _step in STEPS_PER_MINUTE:
				_livestock.update(STEP_SECONDS, _world, _state.player.position, _state.clock)
			_state.clock.advance(1)
		if (hour + 1) % LIVE_LOOK_EVERY_HOURS == 0:
			digests += _digest() + "\n"
	return digests


## Every animal's place, needs, roost and follow state, and the dice and the searches left.
func _digest() -> String:
	var lines: Array[String] = []
	for animal in _livestock.all():
		var fields := [
			animal.species,
			animal.look,
			"pos=%.3f,%.3f" % [animal.position.x, animal.position.y],
			FarmAnimal.Activity.keys()[animal.activity],
			"hunger=%.4f thirst=%.4f" % [animal.hunger, animal.thirst],
			"housed=%s missed=%s" % [animal.is_housed, animal.missed_roost],
			"goal=%s need=%s" % [animal.goal, animal.goal_need],
			"follow=%d wait=%.3f" % [animal.follow_until_minute, animal.follow_wait_seconds],
			"facing=%d friendship=%d" % [animal.facing, animal.friendship],
		]
		lines.append(" ".join(fields))
	lines.append(
		"eggs=%d searches=%d dice=%d" % [_eggs(), _livestock.searches.made, _livestock.rng.state]
	)
	return "\n".join(lines)


func _assert_digest(digest: String, pinned: String) -> void:
	assert_eq(digest.sha256_text(), pinned, digest)


func test_hours_played_live_end_as_they_did() -> void:
	_assert_digest(_live_digests(LIVE_HOURS), LIVE_DIGEST)


func test_a_skip_over_a_day_ends_as_it_did() -> void:
	_state.simulation.skip(26 * GameClock.MINUTES_PER_HOUR)
	_assert_digest(_digest(), LONG_SKIP_DIGEST)


func test_a_skip_to_midnight_ends_with_the_hens_in_the_coop_as_it_did() -> void:
	_state.simulation.skip(12 * GameClock.MINUTES_PER_HOUR)
	_assert_digest(_digest(), SKIP_TO_MIDNIGHT_DIGEST)


func test_a_short_skip_by_day_ends_as_it_did() -> void:
	_state.simulation.skip(2 * GameClock.MINUTES_PER_HOUR)
	_assert_digest(_digest(), SHORT_SKIP_DIGEST)
