extends GutTest
## What the player wears: it counts toward the carried weight, shows on the character and is
## saved.

var _equipment: Equipment


func before_each() -> void:
	_equipment = Equipment.new()


func _through_json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func _layer_slots(player: PlayerState) -> Array:
	return player.appearance.layers.map(func(layer: Dictionary) -> StringName: return layer.slot)


func test_worn_items_count_toward_the_carried_weight() -> void:
	var player := PlayerState.new()
	player.inventory.add(ItemTypes.LOGS, 2)
	player.equipment = Equipment.with_starting_outfit()
	var worn := 0.0
	for item in [ItemTypes.TUNIC, ItemTypes.TROUSERS, ItemTypes.CLOGS]:
		worn += ItemTypes.TYPES[item]["weight"]
	assert_almost_eq(player.carried_weight(), 2.0 + worn, 0.0001)


func test_wearing_an_item_does_not_change_the_carried_weight() -> void:
	var player := PlayerState.new()
	player.inventory.slots[0] = {"item": ItemTypes.SHIRT, "count": 1}
	var before := player.carried_weight()
	player.equipment.quick_equip(player.inventory, 0)
	assert_almost_eq(player.carried_weight(), before, 0.0001)


func test_the_appearance_follows_the_equipment() -> void:
	var player := PlayerState.new()
	player.equipment.equip(Equipment.HEAD, ItemTypes.STRAW_HAT)
	assert_true(Appearance.HEAD in _layer_slots(player))
	player.equipment.equip(Equipment.HEAD, ItemTypes.KNITTED_CAP)
	assert_true(Appearance.HEAD in _layer_slots(player))
	player.equipment.unequip(Equipment.HEAD)
	assert_false(Appearance.HEAD in _layer_slots(player))


func test_a_new_game_wears_a_tunic_and_trousers_and_carries_two_hats_and_a_shirt() -> void:
	var state := GameState.new_game(1)
	assert_eq(state.player.equipment.item_in(Equipment.BODY), ItemTypes.TUNIC)
	assert_eq(state.player.equipment.item_in(Equipment.LEGS), ItemTypes.TROUSERS)
	assert_eq(state.player.inventory.count_of(ItemTypes.STRAW_HAT), 1)
	assert_eq(state.player.inventory.count_of(ItemTypes.KNITTED_CAP), 1)
	assert_eq(state.player.inventory.count_of(ItemTypes.SHIRT), 1)
	assert_true(Appearance.CLOTHES in _layer_slots(state.player))


func test_equipment_round_trip() -> void:
	_equipment.equip(Equipment.HEAD, ItemTypes.STRAW_HAT)
	_equipment.equip(Equipment.BODY, ItemTypes.SHIRT)
	var restored := Equipment.from_dict(_through_json(_equipment.to_dict()))
	assert_eq(restored.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)
	assert_eq(restored.item_in(Equipment.BODY), ItemTypes.SHIRT)
	assert_eq(restored.item_in(Equipment.LEGS), ItemTypes.NONE)


func test_a_saved_player_keeps_what_they_wear_and_how_they_look() -> void:
	var state := GameState.new_game(1)
	state.player.equipment.equip(Equipment.HEAD, ItemTypes.STRAW_HAT)
	var restored := PlayerState.from_dict(_through_json(state.player.to_dict()), state.world)
	assert_eq(restored.equipment.item_in(Equipment.HEAD), ItemTypes.STRAW_HAT)
	assert_eq(restored.appearance.layers, state.player.appearance.layers)


func test_loading_skips_unknown_items_and_items_in_the_wrong_slot() -> void:
	var restored := Equipment.from_dict(
		{"head": "removed_item", "body": "straw_hat", "legs": "trousers"}
	)
	assert_eq(restored.item_in(Equipment.HEAD), ItemTypes.NONE)
	assert_eq(restored.item_in(Equipment.BODY), ItemTypes.NONE)
	assert_eq(restored.item_in(Equipment.LEGS), ItemTypes.TROUSERS)
