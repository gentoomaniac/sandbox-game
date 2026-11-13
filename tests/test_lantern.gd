extends GutTest
## The lantern (task 177): the use key lights it and puts it out while it is held; lit and
## carried it casts its light around the player, wherever they go.

var _state: GameState
var _inventory: Inventory


func before_each() -> void:
	_state = GameState.new_game(7)
	_inventory = _state.player.inventory
	_inventory.slots[7] = {"item": ItemTypes.LANTERN, "count": 1}
	_inventory.select(7)


func _held_variant() -> Variant:
	for layer in _state.player.appearance.layers:
		if layer.slot == Appearance.HELD:
			return layer.variant
	return null


func test_the_held_lantern_is_lit_and_put_out_and_shows_so_in_the_hand() -> void:
	assert_false(_state.player.is_lantern_lit, "a new lantern is out")
	assert_eq(_held_variant(), "lantern")

	assert_true(_state.switch_held_lantern())
	assert_true(_state.player.is_lantern_lit)
	assert_true(_state.player.is_lantern_shining())
	assert_eq(_held_variant(), "lantern_lit")

	assert_true(_state.switch_held_lantern())
	assert_false(_state.player.is_lantern_lit)
	assert_false(_state.player.is_lantern_shining())
	assert_eq(_held_variant(), "lantern")


func test_nothing_but_the_held_lantern_is_switched() -> void:
	_inventory.select(0)
	assert_false(_state.switch_held_lantern(), "the hoe in the hand")
	assert_false(_state.player.is_lantern_lit)
	_inventory.slots[0] = {}
	assert_false(_state.switch_held_lantern(), "an empty hand")
	assert_false(_state.player.is_lantern_lit)


func test_switching_tells_an_outcome_that_pops() -> void:
	var told: Array[ActionOutcome] = []
	_state.action_done.connect(func(outcome: ActionOutcome) -> void: told.append(outcome))
	_state.switch_held_lantern()
	assert_eq(told.size(), 1)
	assert_eq(told[0].kind, ActionOutcome.SWITCH_LANTERN)
	assert_eq(told[0].tile, _state.player.tile())
	assert_eq(SoundEvents.action(told[0].kind), &"item_pickup")


func test_a_lit_lantern_shines_only_in_the_hand() -> void:
	_state.switch_held_lantern()
	_inventory.select(0)
	assert_false(_state.player.is_lantern_shining(), "the hoe in the hand, the lantern in the bag")
	assert_eq(_held_variant(), "rusty_iron_hoe")
	assert_true(_state.player.is_lantern_lit, "it is still lit in the bag")
	_inventory.select(7)
	assert_true(_state.player.is_lantern_shining(), "held again, it shines again")
	_inventory.slots[7] = {}
	assert_false(_state.player.is_lantern_shining(), "no lantern in the hand")


func test_the_lantern_comes_from_give_and_has_no_recipe() -> void:
	var console := Console.new(_state)
	_inventory.slots[7] = {}
	console.run("give lantern")
	assert_eq(_inventory.count_of(ItemTypes.LANTERN), 1)
	var rules := RecipeRules.default_rules()
	for recipe_id in rules.recipe_ids():
		assert_ne(rules.result(recipe_id), ItemTypes.LANTERN, recipe_id)


func test_the_lit_lantern_lights_around_the_player_as_they_walk() -> void:
	var view: PlayerView = add_child_autofree(PlayerView.new())
	view.show_player(_state.player)
	view.light_strength = 1.0
	var light: ObjectLight = view._lantern
	await wait_process_frames(1)
	assert_false(light.visible, "out")

	_state.switch_held_lantern()
	await wait_process_frames(1)
	assert_true(light.visible, "lit")
	assert_eq(light.strength, 1.0)
	assert_almost_eq(light.texture_scale * ObjectLight.TEXTURE_SIZE / 2.0, 5.0 * 32.0, 0.01)
	var feet := light.global_position - PlayerView.LANTERN_POSITION
	assert_eq(feet, view.global_position, "at the hand")

	_state.player.position += Vector2(3, 2)
	await wait_process_frames(1)
	assert_eq(light.global_position, view.global_position + PlayerView.LANTERN_POSITION)
	assert_eq(view.position, (_state.player.position * 32.0).round(), "followed the player")

	view.light_strength = 0.0
	await wait_process_frames(1)
	assert_false(light.visible, "lit, but in daylight")

	view.light_strength = 0.5
	_state.switch_held_lantern()
	await wait_process_frames(1)
	assert_false(light.visible, "put out")
