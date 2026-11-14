extends GutTest
## The plain words crops tell the player: what the seeds' crops like (in the seed tooltips).

## Per crop: the weather it likes, the water it needs, the wind it stands and its days.
const CROP_LIKES := {
	&"turnip": ["cool", "middle", "hardy", "About 9 days in good weather"],
	&"potato": ["cool", "middle", "hardy", "About 11 days in good weather"],
	&"carrot": ["cool", "middle", "hardy", "About 11 days in good weather"],
	&"cabbage": ["cool", "high", "hardy", "About 11 days in good weather"],
	&"onion": ["cool", "middle", "hardy", "About 12 days in good weather"],
	&"wheat": ["cool", "middle", "hardy", "About 12 days in good weather"],
	&"rye": ["cool", "low", "hardy", "About 13 days in good weather"],
	&"buckwheat": ["warm", "low", "tender", "About 8 days in good weather"],
	&"peas": ["cool", "high", "tender", "About 11 days in good weather, then about 4 again"],
	&"beans": ["warm", "middle", "tender", "About 10 days in good weather, then about 3 again"],
	&"flax": ["cool", "high", "tender", "About 11 days in good weather"],
	&"strawberries": ["cool", "high", "hardy", "About 10 days in good weather, then about 3 again"],
	&"pumpkin": ["warm", "high", "hardy", "About 14 days in good weather"],
}


func test_every_crop_has_its_words_in_the_tests() -> void:
	var crop_ids := CropRules.default_rules().crop_ids()
	crop_ids.sort()
	var tested_ids := CROP_LIKES.keys()
	tested_ids.sort()
	assert_eq(tested_ids, crop_ids)


func test_seeds_say_what_their_crop_likes() -> void:
	for crop_id: StringName in CROP_LIKES:
		var seed_id: StringName = CropRules.default_rules().crop(crop_id)["seed"]
		var lines := ItemTooltip.text_for(seed_id).split("\n")
		var likes: Array = CROP_LIKES[crop_id]
		assert_has(lines, "Likes %s weather" % likes[0], crop_id)
		assert_has(lines, "Water need: " + likes[1], crop_id)
		assert_has(lines, "Wind: " + likes[2], crop_id)
		assert_has(lines, likes[3], crop_id)


func test_tree_seeds_say_nothing_about_weather() -> void:
	assert_false("Wind:" in ItemTooltip.text_for(ItemTypes.ACORN))
