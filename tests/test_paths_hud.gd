extends GutTest
## The F4 overlay: the path of the villager nearest the player that is on a trip.

var _state: GameState
var _hud: PathsHud


func before_each() -> void:
	_state = GameState.new_game(7)
	_hud = PathsHud.new()
	_hud.setup(_state.npcs, _state.player)
	add_child_autofree(_hud)


func _label() -> Label:
	return _hud.find_children("*", "Label", false, false)[0]


func test_it_is_hidden_and_asks_for_nothing_until_it_is_toggled() -> void:
	assert_false(_hud.visible)
	assert_false(_hud.is_processing())
	_hud.toggle()
	assert_true(_hud.visible)
	assert_true(_hud.is_processing())
	_hud.toggle()
	assert_false(_hud.is_processing())


func test_it_shows_the_trip_of_a_villager_and_nothing_when_none_is_on_one() -> void:
	_hud.toggle()
	_hud._process(0.0)
	assert_eq(_label().text, "")
	var npc := Npc.create(7, _state.player.position, _state.npcs.rules)
	_state.npcs.add(npc)
	_state.npcs.walk_to(npc, npc.tile() + Vector2i(5, 0), _state.world)
	_hud._process(0.0)
	assert_string_contains(_label().text, "path ")
	assert_string_contains(_label().text, str(npc.tile() + Vector2i(5, 0)))
