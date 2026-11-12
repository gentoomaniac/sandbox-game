extends EnergyCase
## Strength sets the weight that costs no extra energy; nothing is ever refused for being heavy.


func test_a_stronger_character_pays_less_for_the_same_load() -> void:
	_state.player.inventory.add(ItemTypes.STONE, 40)
	_hold(ItemTypes.HOE)
	_state.use_facing_tile()
	var weak_cost := 100.0 - _state.player.energy
	_state.player.energy = 100.0
	_state.player.attributes.set_level(Attributes.STRENGTH, 40)
	_state.use_facing_tile()
	assert_lt(100.0 - _state.player.energy, weak_cost)


func test_picking_up_more_than_the_carry_capacity_is_not_refused() -> void:
	var capacity := _state.player.attributes.carry_capacity()
	_state.player.inventory.add(ItemTypes.STONE, 200)
	assert_gt(_state.player.carried_weight(), capacity)
	assert_eq(_state.player.inventory.count_of(ItemTypes.STONE), 200)
