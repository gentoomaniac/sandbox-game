extends GutTest
## The bag's weight label: what is carried, over what the character carries before it tires them.


func test_the_label_shows_the_load_and_the_carry_capacity_and_follows_strength() -> void:
	var state := GameState.new_game(7)
	var screen := BagScreen.new(autofree(HotbarCase.new_hotbar(state.player.inventory)))
	add_child_autofree(screen)
	screen.show_player(state.player)
	assert_eq(screen._weight_label.text, "Carrying %.1f / 40 kg" % state.player.carried_weight())
	state.player.attributes.set_level(Attributes.STRENGTH, 12)
	assert_eq(screen._weight_label.text, "Carrying %.1f / 48 kg" % state.player.carried_weight())
