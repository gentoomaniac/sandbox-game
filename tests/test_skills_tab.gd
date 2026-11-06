extends GutTest
## The skills tab of the character screen: the points of every skill, the total against the cap,
## the Fade buttons, and the keys that open the screen on either tab.

var _state: GameState
var _screen: CharacterScreen


func before_each() -> void:
	_state = GameState.new_game(7)
	_screen = CharacterScreen.new()
	add_child_autofree(_screen)
	_screen.show_player(_state.player)


func _panel() -> SkillsPanel:
	return _screen.find_children("*", "SkillsPanel", true, false)[0]


func _texts() -> Array:
	return _panel().find_children("*", "Label", true, false).map(
		func(label: Label) -> String: return label.text
	)


func _fade_buttons() -> Array:
	return _panel().find_children("*", "Button", true, false)


func test_the_screen_opens_on_the_tab_asked_for_and_toggles_per_tab() -> void:
	_screen.open(CharacterScreen.Tab.SKILLS)
	assert_eq(_screen.current_tab(), CharacterScreen.Tab.SKILLS)
	assert_true(_panel().visible)
	_screen.toggle(CharacterScreen.Tab.CHARACTER)
	assert_true(_screen.is_open(), "the other tab's key switches tabs")
	assert_eq(_screen.current_tab(), CharacterScreen.Tab.CHARACTER)
	assert_false(_panel().visible)
	_screen.toggle(CharacterScreen.Tab.CHARACTER)
	assert_false(_screen.is_open(), "its own key closes it")


func test_every_skill_shows_its_name_and_points_and_the_total_its_cap() -> void:
	_state.player.skills.set_points(&"masonry", 42.5)
	var texts := _texts()
	for skill in SkillRules.default_rules().skill_ids():
		assert_has(texts, SkillRules.default_rules().skill_name(skill))
	assert_has(texts, "42.5")
	assert_has(texts, "0.0")
	assert_has(texts, "Total 42.5 / 200")


func test_a_fade_button_marks_its_skill_to_fade_and_shows_the_mark() -> void:
	var buttons := _fade_buttons()
	assert_eq(buttons.size(), SkillRules.default_rules().skill_ids().size())
	buttons[2].toggled.emit(true)
	assert_true(_state.player.skills.is_fading(&"masonry"))
	assert_eq(buttons[2].text, "Fading")
	_state.player.skills.set_fading(&"masonry", false)
	assert_false(buttons[2].button_pressed, "the button follows the skills")


func test_k_opens_the_skills_and_no_other_action_uses_it() -> void:
	var keys: Array[Key] = []
	for event in InputMap.action_get_events(&"skills"):
		keys.append((event as InputEventKey).physical_keycode)
	assert_eq(keys, [KEY_K] as Array[Key])
	for action in GameSettings.actions():
		if action == &"skills":
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				assert_ne(event.physical_keycode, KEY_K, str(action))
	assert_eq(GameSettings.action_label(&"skills"), "Skills")
	assert_true(GameSettings.ACTION_DESCRIPTIONS.has(&"skills"))
