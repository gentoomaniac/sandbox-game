extends IndoorCase
## E speaks to a villager who is inside the same building as the player, and to no one else while
## the player is in a room (#8).

var _house: Building
var _room: Interior


func before_each() -> void:
	super.before_each()
	_house = _place_house()
	_room = _walk_in(_house)


func _villager_at(room_tile: Vector2i, building: Building) -> Npc:
	var npc := Npc.create(5, building.yard(), _state.npcs.rules)
	npc.inside = building
	npc.inside_position = Vector2(room_tile) + Vector2(0.5, 0.5)
	_state.npcs.add(npc)
	building.inside()
	return npc


func _next_to_player() -> Vector2i:
	return _state.player.tile() + Vector2i.UP


func test_e_speaks_to_a_villager_in_the_same_room() -> void:
	var npc := _villager_at(_next_to_player(), _house)
	assert_eq(Interaction.npc_to_chat(_state, _next_to_player()), npc)
	assert_eq(Interaction.choice_at(_state, _next_to_player()).kind, Interaction.Kind.CHAT)


func test_e_does_not_speak_to_a_villager_in_another_building() -> void:
	var other := Building.new(BuildingTypes.KATE, Vector2i(500, 500))
	_villager_at(_next_to_player(), other)
	assert_null(Interaction.npc_to_chat(_state, _next_to_player()))


func test_e_does_not_speak_to_a_villager_out_in_the_world_who_stands_at_the_same_numbers() -> void:
	var npc := Npc.create(5, Vector2(_next_to_player()) + Vector2(0.5, 0.5), _state.npcs.rules)
	_state.npcs.add(npc)
	assert_null(Interaction.npc_to_chat(_state, _next_to_player()))


func test_a_villager_who_is_spoken_to_turns_to_the_player_in_the_room() -> void:
	var npc := _villager_at(_next_to_player(), _house)
	_state.npcs.talk_to(npc, _state.player.position)
	assert_eq(npc.facing, Vector2i.DOWN)
