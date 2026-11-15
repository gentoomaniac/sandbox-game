extends GutTest
## The rules, the catalog and the pictures that ship with the game are valid (see RulesCheck).


func test_the_shipped_rules_catalog_and_pictures_are_valid() -> void:
	assert_true(RulesCheck.is_everything_valid())
