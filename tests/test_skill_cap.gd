extends GutTest
## The total cap of all skills: at it a skill only grows by taking points from a skill marked to
## fade, and a total above it (the console, a hand-edited save) gives no free room.

const RULES := {
	"cap": {"skill": 100.0, "total": 200.0},
	"gain": {"at_level": 2.0, "trivial_above": 40.0},
	"woodworking": {"name": "Woodworking", "description": "Wood."},
	"cooking": {"name": "Cooking", "description": "Food."},
	"masonry": {"name": "Masonry", "description": "Bricks."},
}


func _skills() -> Skills:
	return Skills.new(SkillRules.new(RULES))


## Skills at the total cap: woodworking 100, cooking 60, masonry 40.
func _skills_at_the_cap() -> Skills:
	var skills := _skills()
	skills.set_points(&"woodworking", 100.0)
	skills.set_points(&"cooking", 60.0)
	skills.set_points(&"masonry", 40.0)
	return skills


func test_below_the_total_cap_a_skill_grows_freely() -> void:
	var skills := _skills()
	skills.set_points(&"woodworking", 100.0)
	skills.set_points(&"cooking", 99.0)
	assert_eq(skills.practise(&"masonry", 0.0), 1.0, "only 1 point left to the total cap")
	assert_eq(skills.total(), 200.0)


func test_at_the_total_cap_nothing_grows_while_no_skill_fades() -> void:
	var skills := _skills_at_the_cap()
	assert_eq(skills.gain_at(&"masonry", 40.0), 2.0, "it would teach")
	assert_eq(skills.practise(&"masonry", 40.0), 0.0)
	assert_eq(skills.points(&"masonry"), 40.0)
	assert_eq(skills.total(), 200.0)


func test_at_the_total_cap_a_skill_grows_by_what_a_fading_one_gives() -> void:
	var skills := _skills_at_the_cap()
	skills.set_fading(&"woodworking", true)
	assert_eq(skills.practise(&"masonry", 40.0), 2.0)
	assert_eq(skills.points(&"masonry"), 42.0)
	assert_eq(skills.points(&"woodworking"), 98.0)
	assert_eq(skills.total(), 200.0)


func test_a_fading_skill_does_not_feed_itself() -> void:
	var skills := _skills_at_the_cap()
	skills.set_fading(&"masonry", true)
	assert_eq(skills.practise(&"masonry", 40.0), 0.0)
	assert_eq(skills.points(&"masonry"), 40.0)


func test_a_fading_skill_with_little_left_gives_that_and_the_next_fading_one_the_rest() -> void:
	var rules := RULES.duplicate(true)
	rules["cap"]["total"] = 150.0
	var skills := Skills.new(SkillRules.new(rules))
	skills.set_points(&"woodworking", 50.0)
	skills.set_points(&"cooking", 0.5)
	skills.set_points(&"masonry", 99.5)
	skills.set_fading(&"cooking", true)
	skills.set_fading(&"masonry", true)
	assert_eq(skills.practise(&"woodworking", 50.0), 2.0)
	assert_eq(skills.points(&"cooking"), 0.0, "the first fading skill in the file gives first")
	assert_eq(skills.points(&"masonry"), 98.0)
	assert_eq(skills.total(), 150.0)


func test_above_the_total_cap_a_skill_takes_only_what_it_learns_from_a_fading_one() -> void:
	var skills := _skills()
	skills.set_points(&"woodworking", 100.0)
	skills.set_points(&"cooking", 100.0)
	skills.set_points(&"masonry", 50.0)
	assert_eq(skills.practise(&"masonry", 50.0), 0.0, "nothing marked to fade")
	assert_eq(skills.points(&"masonry"), 50.0)
	skills.set_fading(&"cooking", true)
	assert_eq(skills.practise(&"masonry", 50.0), 2.0)
	assert_eq(skills.points(&"cooking"), 98.0, "it gives the gain, not the overshoot")
	assert_eq(skills.total(), 250.0)


func test_fading_is_off_until_set_and_can_be_taken_back() -> void:
	var skills := _skills()
	assert_false(skills.is_fading(&"cooking"))
	skills.set_fading(&"cooking", true)
	assert_true(skills.is_fading(&"cooking"))
	skills.set_fading(&"cooking", false)
	assert_false(skills.is_fading(&"cooking"))
