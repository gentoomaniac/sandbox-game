extends GutTest
## The bag's weight and purse labels: what is carried, over what the character carries before it
## tires them, and the Schilling in the purse.


func test_the_label_shows_the_load_and_the_carry_capacity_and_follows_strength() -> void:
	var state := GameFactory.new_game(7)
	var screen := BagScreen.new(autofree(HotbarCase.new_hotbar(state.player.inventory)))
	add_child_autofree(screen)
	screen.show_player(state.player)
	assert_eq(screen._weight_label.text, "Carrying %.1f / 40 kg" % state.player.carried_weight())
	state.player.attributes.set_level(Attributes.STRENGTH, 12)
	assert_eq(screen._weight_label.text, "Carrying %.1f / 48 kg" % state.player.carried_weight())


func test_the_purse_is_shown_in_schilling_and_follows_the_money() -> void:
	var state := GameFactory.new_game(7)
	var screen := BagScreen.new(autofree(HotbarCase.new_hotbar(state.player.inventory)))
	add_child_autofree(screen)
	screen.show_player(state.player)
	assert_eq(screen._purse_label.text, "32 Schilling")
	state.player.purse.add(8)
	assert_eq(screen._purse_label.text, "40 Schilling")
