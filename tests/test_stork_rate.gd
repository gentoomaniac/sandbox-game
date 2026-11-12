extends WildlifeCase
## How often wild storks come (task 202): few at once, and rarely. The numbers are in
## data/wildlife.cfg; these tests hold them to the bounds the player should not see exceeded.
## The rates over a whole game day, near a village and wet meadows, come from tools/bench/storks.gd.

const MIDSUMMER := 45
const NOON := 12 * 60
const KINDS: Array[StringName] = [WildlifeRules.STORK, WildlifeRules.ROOF_STORK]
## A tick of the spawner is a second, which is this many game minutes (see GameClock).
const MINUTES_PER_TICK := 1.5
const TICKS_PER_GAME_HOUR := 40.0
const HOURS := 12
## Wild storks at once, at most.
const MOST_AT_ONCE := 1
## Hunting storks that come in an hour while there is none, on average, at most; roof storks are
## rarer still.
const MOST_ARRIVALS_PER_HOUR := 0.5
const MOST_ROOF_ARRIVALS_PER_HOUR := 0.15
## The gap before one comes back, game minutes, at least.
const LEAST_GAP := 120
## No other kind may crowd a stork out of the view (`max_total`).
const ROOM := 1000


func before_each() -> void:
	super()
	var values := WildlifeRules.default_rules()._values.duplicate(true)
	values["general"]["max_total"] = ROOM
	_wildlife.rules = WildlifeRules.new(values)
	var house := _state.world.place_building(BuildingTypes.KATE, Vector2i(3, 8))
	_camera.rig.position = _wildlife._front_middle(house)
	_state.clock.day = MIDSUMMER
	_state.weather_override = &"clear"


func test_few_storks_are_about_at_once_at_any_hour() -> void:
	for kind in KINDS:
		for hour in 24:
			var target := _wildlife.rules.target_count(
				kind, MIDSUMMER, hour * 60, _state.current_weather()
			)
			assert_lte(target, MOST_AT_ONCE, "%s at %d h" % [kind, hour])


func test_a_stork_comes_in_few_hours() -> void:
	var weather := _state.current_weather()
	var rules := _wildlife.rules
	for kind in KINDS:
		var chance := rules.spawn_chance(kind, MIDSUMMER, NOON, weather)
		var per_hour := chance * TICKS_PER_GAME_HOUR
		var most := MOST_ARRIVALS_PER_HOUR
		if kind == WildlifeRules.ROOF_STORK:
			most = MOST_ROOF_ARRIVALS_PER_HOUR
		assert_lte(per_hour, most, "%s per game hour with none there" % kind)
		assert_gte(rules.return_gap_minutes(kind), LEAST_GAP, "%s gap" % kind)


## The worst case: every roof stork that comes is gone at once (it flies off), and the view has
## a roof free for the next. Only the gap keeps the next from coming at once.
func test_roof_storks_that_leave_at_once_come_back_only_after_the_gap() -> void:
	_state.clock.set_time(8, 0)
	var arrivals := 0
	for tick in roundi(HOURS * TICKS_PER_GAME_HOUR):
		_wildlife._match_counts()
		if _wildlife._count_of(WildlifeRules.ROOF_STORK) > 0:
			arrivals += 1
			assert_lte(_wildlife._count_of(WildlifeRules.ROOF_STORK), MOST_AT_ONCE)
			for stork in _animals_of(Stork):
				stork.is_done = true
			_wildlife._remove_gone_animals()
		if tick % 2 == 1:
			_state.clock.advance(roundi(2.0 * MINUTES_PER_TICK))
	var gap := _wildlife.rules.return_gap_minutes(WildlifeRules.ROOF_STORK)
	assert_lte(arrivals, HOURS * 60 / gap + 1, "arrivals in %d game hours" % HOURS)
