extends GutTest
## The skills tab of the character screen: the points of every skill, the total against the cap,
## the Fade buttons, and the keys that open the screen on either tab.

var _state: GameState
var _screen: CharacterScreen


func before_each() -> void:
	_state = GameState.new_game(7)
	_screen = CharacterScreen.new(autofree(HotbarCase.new_hotbar()))
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
	_screen.open_tab(CharacterScreen.Tab.SKILLS)
	assert_eq(_screen.current_tab(), CharacterScreen.Tab.SKILLS)
	assert_true(_panel().visible)
	_screen.toggle_tab(CharacterScreen.Tab.CHARACTER)
	assert_true(_screen.is_open(), "the other tab's key switches tabs")
	assert_eq(_screen.current_tab(), CharacterScreen.Tab.CHARACTER)
	assert_false(_panel().visible)
	_screen.toggle_tab(CharacterScreen.Tab.CHARACTER)
	assert_false(_screen.is_open(), "its own key closes it")


func test_a_plain_open_shows_the_character_even_after_the_skills() -> void:
	_screen.toggle_tab(CharacterScreen.Tab.SKILLS)
	_screen.close()
	_screen.open()
	assert_eq(_screen.current_tab(), CharacterScreen.Tab.CHARACTER)


func test_the_screen_closes_on_escape_and_when_another_window_opens() -> void:
	_screen.open()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	_screen._unhandled_input(escape)
	assert_false(_screen.is_open())
	_screen.open()
	var other := CraftingScreen.new()
	add_child_autofree(other)
	other.show_crafting(Crafting.new(_state), _state.player.inventory)
	other.open()
	assert_false(_screen.is_open())


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


func test_in_a_short_window_the_rows_scroll_and_the_total_stays_in_view() -> void:
	var window := SubViewport.new()
	window.size = Vector2i(640, 100)
	add_child_autofree(window)
	var screen := CharacterScreen.new(autofree(HotbarCase.new_hotbar()))
	window.add_child(screen)
	screen.show_player(_state.player)
	screen.open_tab(CharacterScreen.Tab.SKILLS)
	await wait_process_frames(3)
	var panel: SkillsPanel = screen.find_children("*", "SkillsPanel", true, false)[0]

	assert_lt(panel.list.size.y, panel.list.get_child(0).size.y, "the rows scroll")
	assert_lte(panel.list.get_global_rect().end.y, 100.0, "the list ends inside the window")
	for label: Label in panel.find_children("*", "Label", true, false):
		if label.text.begins_with("Total") or label.text.begins_with("Your skills together"):
			assert_gte(label.get_global_rect().position.y, panel.list.get_global_rect().end.y)
	var fade_of_last_skill: Button = panel.find_children("*", "Button", true, false)[-1]
	fade_of_last_skill.grab_focus()
	await wait_process_frames(3)
	assert_gt(panel.list.scroll_vertical, 0, "focus moving to a row scrolls to it")
