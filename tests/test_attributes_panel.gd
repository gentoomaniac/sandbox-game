extends GutTest
## The attributes on the character tab: the levels, a bonus beside its level, and the numbers
## the attributes give.

var _state: GameState
var _panel: AttributesPanel


func before_each() -> void:
	_state = GameState.new_game(7)
	var screen := CharacterScreen.new(autofree(HotbarCase.new_hotbar()))
	add_child_autofree(screen)
	screen.show_player(_state.player)
	_panel = screen.find_children("*", "AttributesPanel", true, false)[0]


func _texts() -> Array:
	return _panel.find_children("*", "Label", true, false).map(
		func(label: Label) -> String: return label.text
	)


func test_a_new_character_shows_its_levels_and_what_they_give() -> void:
	assert_eq(
		_texts(),
		[
			"Strength",
			"10",
			"Agility",
			"10",
			"Stamina",
			"10",
			"HP",
			"10",
			"Max energy",
			"100",
			"Max health",
			"100",
			"Carry capacity",
			"40 kg",
		]
	)


func test_a_level_and_a_bonus_show_and_the_numbers_follow() -> void:
	_state.player.attributes.set_level(Attributes.STRENGTH, 12)
	_state.player.attributes.add_bonus(&"stew", Attributes.STAMINA, 2)
	var texts := _texts()
	assert_has(texts, "12")
	assert_has(texts, "10 (+2)")
	assert_has(texts, "120")
	assert_has(texts, "48 kg")


func test_every_attribute_has_a_tooltip() -> void:
	var tips := _panel.find_children("*", "Label", true, false).filter(
		func(label: Label) -> bool: return label.has_meta(TooltipView.TEXT_META)
	)
	assert_eq(tips.size(), 4)
