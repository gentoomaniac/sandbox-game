extends WildlifeCase
## Taking every wild animal of a kind away at once (the `killall` console command).


func test_every_animal_of_the_kind_goes_and_the_others_stay() -> void:
	_wildlife.place(WildlifeRules.BIRD, VIEW_CENTRE)
	_wildlife.place(WildlifeRules.BIRD, VIEW_CENTRE + Vector2(8, 0))
	_wildlife.place(WildlifeRules.DEER, VIEW_CENTRE + Vector2(0, 8))
	var deer := _animals_of(Deer)
	assert_eq(_wildlife.remove_kind(WildlifeRules.BIRD), 2)
	assert_eq(_wildlife._animals, deer)
	assert_eq(_wildlife.remove_kind(WildlifeRules.BIRD), 0)


func test_the_removed_are_freed() -> void:
	_wildlife.place(WildlifeRules.SQUIRREL, VIEW_CENTRE)
	var squirrel := _animals_of(Squirrel)[0]
	_wildlife.remove_kind(WildlifeRules.SQUIRREL)
	await wait_process_frames(2)
	assert_false(is_instance_valid(squirrel))


func test_a_mouse_a_cat_is_after_is_no_longer_about() -> void:
	_wildlife.place(WildlifeRules.MOUSE, VIEW_CENTRE)
	var mouse: Mouse = _animals_of(Mouse)[0]
	_wildlife.remove_kind(WildlifeRules.MOUSE)
	mouse.sync_prey()
	assert_false(mouse.prey.is_about)


func test_a_flock_goes_by_its_own_kind_and_a_stork_stays() -> void:
	_wildlife.place(WildlifeRules.STORK, VIEW_CENTRE)
	_wildlife.place(WildlifeRules.GEESE, VIEW_CENTRE + Vector2(8, 0))
	assert_eq(_wildlife.remove_kind(WildlifeRules.GEESE), 1)
	assert_eq(_animals_of(Stork).size(), 1)
