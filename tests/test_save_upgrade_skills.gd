extends SaveUpgradeCase
## Version 14 saves have the player's skills: an older save starts with none (see SaveFile).


func test_a_version_13_save_loads_with_no_skill_points() -> void:
	var game := _current_game()
	game["player"].erase("skills")
	_write_save(13, game)

	var restored := SaveFile.read(SAVE_PATH)

	for skill in SkillRules.default_rules().skill_ids():
		assert_eq(restored.player.skills.points(skill), 0.0, str(skill))
