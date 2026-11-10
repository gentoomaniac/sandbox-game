extends WildlifeCase
## A cat hunting the mice of the view (Livestock decides the hunt, the views show it): it sees a
## mouse within its sight and not beyond; it crouches, creeps up and pounces, and the mouse is
## caught or dashes off into cover; it rests after a hunt, and an asleep cat hunts nothing; a hunt
## ends cleanly when the cat's view or the mice go. Time passes in steps of the livestock and the
## views together, never by the frame rate.

const MEADOW := Vector2i(-12, 8)
## Livestock moves its animals no further than this in one step.
const CAT_STEP := Livestock.MAX_STEP_SECONDS
const NOON := 12 * 60
const MIDNIGHT := 0

var _livestock: Livestock
var _cat: FarmAnimal
var _cat_view: FarmAnimalView
var _mouse: Mouse


func before_each() -> void:
	super()
	for y in range(MEADOW.y - 4, MEADOW.y + 5):
		for x in range(MEADOW.x - 4, MEADOW.x + 8):
			_state.world.set_terrain(Vector2i(x, y), Tile.Terrain.GRASS)
			_state.world.remove_object(Vector2i(x, y))
	_camera.rig.position = TerrainTileset.tile_centre(MEADOW)
	_state.clock.minute_of_day = NOON
	_livestock = _state.livestock
	# This test keeps the seed it had before WildlifeCase seeded the view: its own, not SEED.
	_livestock.rng.seed = 3
	_wildlife.rng.seed = 3
	_cat = FarmAnimal.new(LivestockRules.CAT, &"ginger", Vector2(MEADOW) + Vector2(0.5, 0.5))
	_livestock.add(_cat)
	_wildlife._show_farm_animal_if_near(_cat)
	_cat_view = _wildlife._farm_animals[_cat]


## Puts the mouse `tiles` right of the cat.
func _mouse_ahead(tiles: float) -> void:
	var point := _cat_view.position + Vector2(tiles * WildlifeRules.TILE_SIZE, 0.0)
	_wildlife._spawn(WildlifeRules.MOUSE, point, true)
	_mouse = _animals_of(Mouse).back()


## Hunting rules whose pounces always catch (1) or never do (0).
func _catch_chance(chance: float) -> void:
	var values := DataFile.read_sections(LivestockRules.DEFAULT_PATH)
	values["hunting"]["catch_chance"] = chance
	_livestock.rules = LivestockRules.new(values)


## Lets this many seconds pass for the cat (Livestock moves it and hunts, its view shows it). The
## mouse is left sitting where it is, unless a cat's hunt has made it flee or be caught.
func _run_cat(seconds: float, minute := NOON) -> void:
	for _i in roundi(seconds / CAT_STEP):
		_state.clock.minute_of_day = minute
		if is_instance_valid(_mouse):
			_mouse.sync_prey()
		_livestock.update(CAT_STEP, _state.world, Vector2(1000, 1000), _state.clock)
		if is_instance_valid(_cat_view):
			_cat_view._process(CAT_STEP)
		if (
			is_instance_valid(_mouse)
			and (_mouse._state == Mouse.FLEE or _mouse.prey.fate != Prey.Fate.NONE)
		):
			_mouse._process(CAT_STEP)


## Runs the cat until its hunt is over (for at most 30 s) and returns the states its view went
## through, from the first step on.
func _run_hunt() -> Array[StringName]:
	var states: Array[StringName] = []
	_cat_view.state_entered.connect(func(state: StringName) -> void: states.append(state))
	for _i in roundi(30.0 / CAT_STEP):
		_run_cat(CAT_STEP)
		if not states.is_empty() and states.back() == &"idle":
			break
	return states


func test_a_cat_sees_a_mouse_within_its_sight() -> void:
	_mouse_ahead(_livestock.rules.hunting("sight_tiles") - 0.5)
	_run_cat(CAT_STEP)
	assert_eq(_cat.activity, FarmAnimal.Activity.CROUCH)


func test_a_cat_takes_no_notice_of_a_mouse_beyond_its_sight() -> void:
	_mouse_ahead(_livestock.rules.hunting("sight_tiles") + 0.5)
	var states := {}
	_cat_view.state_entered.connect(func(state: StringName) -> void: states[state] = true)
	var start := _cat.position
	for _i in roundi(20.0 / CAT_STEP):
		# Kept where it is, so that it never wanders into sight of the mouse.
		_cat.position = start
		_run_cat(CAT_STEP)
	assert_gt(states.size(), 1, "it picked what to do next, and looked about each time")
	assert_false(states.has(&"crouch"))


func test_a_pounce_that_catches_takes_the_mouse() -> void:
	_catch_chance(1.0)
	_mouse_ahead(3.0)
	var states := _run_hunt()
	assert_eq(states, [&"crouch", &"creep", &"pounce", &"idle"] as Array[StringName])
	assert_true(_mouse.is_done, "caught")
	assert_ne(_mouse._state, Mouse.FLEE)


func test_a_mouse_that_sees_the_pounce_coming_dashes_off_into_cover() -> void:
	_catch_chance(0.0)
	_mouse_ahead(3.0)
	_run_cat(1.0)
	assert_eq(_mouse._state, Mouse.SIT, "it takes no notice of the cat creeping up")
	for _i in roundi(30.0 / CAT_STEP):
		if _cat.activity == FarmAnimal.Activity.POUNCE:
			break
		_run_cat(CAT_STEP)
	assert_eq(_cat.activity, FarmAnimal.Activity.POUNCE)
	assert_eq(_mouse._state, Mouse.FLEE)
	assert_gt(_mouse._direction.x, 0.0, "away from the cat")
	_run_cat(Mouse.FLEE_SECONDS + CAT_STEP)
	assert_true(_mouse.is_done, "gone into cover")
	assert_eq(_cat.activity, FarmAnimal.Activity.IDLE)


func test_a_cat_gives_up_a_mouse_that_is_gone() -> void:
	_mouse_ahead(3.0)
	_run_cat(1.0)
	_mouse.is_done = true
	_run_cat(CAT_STEP)
	assert_eq(_cat.activity, FarmAnimal.Activity.IDLE)


func test_a_cat_rests_after_a_hunt_with_another_mouse_in_sight() -> void:
	_catch_chance(1.0)
	_mouse_ahead(3.0)
	_run_hunt()
	_mouse_ahead(2.0)
	var hunted_at := -1.0
	var seconds := 0.0
	while hunted_at < 0.0 and seconds < _livestock.rules.hunting("rest_seconds") + 30.0:
		# Two tiles ahead of the cat wherever it wanders, always in sight.
		_mouse.position = _cat_view.position + Vector2(2.0 * WildlifeRules.TILE_SIZE, 0.0)
		_run_cat(CAT_STEP)
		seconds += CAT_STEP
		if _cat.activity == FarmAnimal.Activity.CROUCH:
			hunted_at = seconds
	assert_gt(hunted_at, _livestock.rules.hunting("rest_seconds"), "rested first")


func test_an_asleep_cat_hunts_no_mouse() -> void:
	_mouse_ahead(2.0)
	_run_cat(10.0, MIDNIGHT)
	assert_eq(_cat.activity, FarmAnimal.Activity.SLEEP)
	assert_false(_mouse.is_done)
