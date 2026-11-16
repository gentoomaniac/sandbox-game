extends ResourceCase
## The use of a tool with a swing (UseSwing): the tile is used when the blow lands, with the energy
## and the sounds, and a second use waits for the end of the swing.

const STEP := 0.01

var _view: PlayerView
var _swing: UseSwing
var _results: Array[ToolUse.Use] = []
var _rules := ToolSwingRules.default_rules()


func before_each() -> void:
	super.before_each()
	_results.clear()
	_view = PlayerView.new()
	add_child_autofree(_view)
	_view.show_player(_state.player)
	_swing = UseSwing.new(_state, _view)
	_swing.used.connect(func(result: ToolUse.Use, _tile: Vector2i) -> void: _results.append(result))


func test_a_tool_is_used_at_the_strike_frame_and_not_before() -> void:
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	_hold(ItemTypes.RUSTY_IRON_HOE)
	assert_true(_swing.use_on(_facing_target()))
	assert_eq(
		_world.tile_at(_tile).terrain, Tile.Terrain.GRASS, "nothing at the start of the swing"
	)
	_run(_rules.frame_start(&"chop", _rules.strike_frame(&"chop")) - 2 * STEP)
	assert_eq(_results, [])
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.GRASS)
	_run(3 * STEP)
	assert_eq(_results, [ToolUse.Use.TILL])
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)


func test_the_energy_is_spent_with_the_blow() -> void:
	_hold(ItemTypes.RUSTY_IRON_HOE)
	var energy := _state.player.energy
	_swing.use_on(_facing_target())
	assert_eq(_state.player.energy, energy)
	_run(_rules.duration(&"chop"))
	assert_lt(_state.player.energy, energy)


func test_a_second_use_during_the_swing_is_refused() -> void:
	_hold(ItemTypes.RUSTY_IRON_HOE)
	assert_true(_swing.use_on(_facing_target()))
	_run(0.05)
	assert_false(_swing.use_on(_facing_target()))
	_run(_rules.duration(&"chop"))
	assert_eq(_results.size(), 1, "one blow for the two uses")


func test_a_use_after_the_swing_swings_again() -> void:
	_hold(ItemTypes.RUSTY_IRON_SHOVEL)
	_swing.use_on(_facing_target())
	_run(_rules.duration(&"dig") + STEP)
	assert_true(_swing.use_on(_facing_target()))
	assert_true(_view.is_swinging())


func test_a_use_that_is_no_swing_is_done_at_once() -> void:
	_hold(ItemTypes.NONE)
	_swing.use_on(_facing_target())
	assert_eq(_results.size(), 1)
	assert_false(_view.is_swinging())


func test_a_tool_that_does_nothing_on_the_tile_does_not_swing() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_hold(ItemTypes.RUSTY_IRON_WATERING_CAN)
	_state.player.can_water = 0
	_swing.use_on(_facing_target())
	assert_eq(_results, [ToolUse.Use.CAN_EMPTY])
	assert_false(_view.is_swinging())


func test_changing_the_item_during_the_swing_uses_nothing() -> void:
	_hold(ItemTypes.RUSTY_IRON_HOE)
	_swing.use_on(_facing_target())
	_hold(ItemTypes.RUSTY_IRON_AXE)
	_run(_rules.duration(&"chop"))
	assert_eq(_results, [])


func _facing_target() -> Targeting:
	return Targeting.resolve(
		_state.player.tile(), _state.player.facing_tile(), Vector2i.ZERO, false
	)


## Lets the view process frames of STEP seconds for `seconds`.
func _run(seconds: float) -> void:
	for step in roundi(seconds / STEP):
		_view._process(STEP)


func test_getting_on_a_horse_during_the_swing_ends_it_with_no_blow() -> void:
	_hold(ItemTypes.RUSTY_IRON_HOE)
	_swing.use_on(_facing_target())
	_run(0.05)
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", _state.player.position)
	horse.is_saddled = true
	_state.livestock.add(horse)
	_state.travel.mount(_state, horse)
	_run(_rules.duration(&"chop"))
	assert_false(_view.is_swinging())
	assert_eq(_results, [], "no blow")


func test_going_to_bed_during_the_swing_ends_it_with_no_blow() -> void:
	_hold(ItemTypes.RUSTY_IRON_HOE)
	_swing.use_on(_facing_target())
	_run(0.05)
	var bed := WorldObject.new(WorldObjectTypes.SMALL_BED, _tile + Vector2i(2, -1))
	_world.add_object(bed)
	_state.player.bed_lying_in = bed
	_run(_rules.duration(&"chop"))
	assert_false(_view.is_swinging())
	assert_eq(_results, [], "no blow")
