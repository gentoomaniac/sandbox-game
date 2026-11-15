extends ResourceCase
## Someone standing where a building would go: the player, a villager or a farm animal stops it,
## so no one is shut in its walls.

var _builder: Builder


func before_each() -> void:
	super.before_each()
	_builder = Builder.new(_state)
	for item: StringName in _builder.costs():
		_state.player.inventory.add(item, _builder.costs()[item])


## A top left tile near the camp where the chosen building can be placed.
func _open_origin() -> Vector2i:
	for y in range(-24, 25):
		for x in range(-24, 25):
			var origin := _state.player.tile() + Vector2i(x, y)
			if _builder.placement_blockers(origin).is_empty():
				return origin
	fail_test("no room for a %s near the camp" % _builder.choice)
	return Vector2i.ZERO


func test_a_spot_the_player_stands_on_is_refused() -> void:
	var origin := _open_origin()
	_state.player.position = Vector2(origin) + Vector2(0.5, 0.5)
	assert_eq(_builder.placement_blockers(origin), {origin: World.Blocked.OCCUPIED})
	assert_null(_builder.place(origin), "the player is not walled in")


func test_a_spot_a_villager_stands_on_is_refused() -> void:
	var origin := _open_origin()
	var npc := _state.npcs.spawn_villager("antje", Vector2(origin), _world)
	assert_not_null(npc)
	npc.position = Vector2(origin) + Vector2(0.5, 0.5)
	assert_eq(_builder.placement_blockers(origin), {npc.tile(): World.Blocked.OCCUPIED})
	assert_null(_builder.place(origin))


func test_a_spot_the_players_body_reaches_into_is_refused() -> void:
	# The feet a little west of the footprint, the body over its edge: the feet tile alone would
	# let the house go up over the player.
	var origin := _open_origin()
	_state.player.position = Vector2(origin) + Vector2(-0.1, 0.5)
	assert_ne(_state.player.tile(), origin)
	assert_eq(_builder.placement_blockers(origin), {origin: World.Blocked.OCCUPIED})
	assert_null(_builder.place(origin))


func test_a_spot_a_farm_animal_stands_on_is_refused() -> void:
	var origin := _open_origin()
	assert_eq(_state.livestock.spawn(LivestockRules.COW, 1, Vector2(origin), _world), 1)
	var cow: FarmAnimal = _state.livestock.all()[-1]
	cow.position = Vector2(origin) + Vector2(0.5, 0.5)
	assert_eq(_builder.placement_blockers(origin), {origin: World.Blocked.OCCUPIED})
	assert_null(_builder.place(origin))
