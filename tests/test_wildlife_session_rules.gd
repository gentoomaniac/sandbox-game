extends GutTest
## Each game has wildlife rules of its own sun; the cached default rules are never written.


func test_rules_for_a_session_carry_its_sun_and_leave_the_default_rules_alone() -> void:
	var default_sun := WildlifeRules.default_rules().sun
	var session_sun := Sun.new()
	var session_rules := WildlifeRules.for_session(session_sun)
	assert_same(session_rules.sun, session_sun)
	assert_same(WildlifeRules.default_rules().sun, default_sun)
	assert_ne(session_rules, WildlifeRules.default_rules())
	assert_eq(
		session_rules.general("tick_seconds"), WildlifeRules.default_rules().general("tick_seconds")
	)
