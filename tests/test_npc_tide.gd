extends NpcCase
## The tide and the villagers: they keep off mud under water, and one caught in it by the rising
## water walks out. The tests' noon of day 45 falls at high water.

## The east half of the yard is tidal mud.
const FIRST_MUD_COLUMN := 2


func before_each() -> void:
	super()
	for y in range(-YARD_RADIUS, YARD_RADIUS + 1):
		for x in range(FIRST_MUD_COLUMN, YARD_RADIUS + 1):
			_world.set_terrain(_middle + Vector2i(x, y), Tile.Terrain.MUD)
	_state.clock.day = DAY
	_state.clock.minute_of_day = NOON
	assert_gt(Tide.level(_state.clock.total_minutes()), 0.99, "high water")


func _column_of(npc: Npc) -> int:
	return npc.tile().x - _middle.x


func test_villagers_keep_off_flooded_mud() -> void:
	var npc := _add_villager(_yard_middle() + Vector2(-1.0, 0.0), _yard_middle())
	for _step_index in int(240.0 / STEP_SECONDS):
		_step()
		assert_lt(_column_of(npc), FIRST_MUD_COLUMN, "in the water at %s" % npc.position)


func test_a_villager_in_the_rising_water_walks_out_of_it() -> void:
	var npc := _add_villager(_yard_middle() + Vector2(FIRST_MUD_COLUMN + 1.0, 0.0), _yard_middle())
	var was_out := false
	for _step_index in int(240.0 / STEP_SECONDS):
		_step()
		was_out = was_out or _column_of(npc) < FIRST_MUD_COLUMN
	assert_true(was_out, "it got out of the water")


func test_a_catch_up_puts_no_villager_in_the_water() -> void:
	for _index in 8:
		_add_villager(_yard_middle(), _yard_middle())
	_step()
	for seed_value in 10:
		_npcs.catch_up(_world, seed_value)
		for npc in _npcs.all():
			assert_lt(_column_of(npc), FIRST_MUD_COLUMN, str(npc.position))
