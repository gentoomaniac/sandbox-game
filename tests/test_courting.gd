extends GutTest
## Whether courting may start (Benefits `may_court`): only at level 10, only for a sheet that allows
## romance, only for a villager with no bond. Nothing starts a bond yet.

var _state: GameState
var _boy: Npc
var _friendship := FriendshipRules.default_rules()
var _villagers: VillagerRules


func before_each() -> void:
	_state = GameState.new_game(7)
	_boy = Npc.create_villager("boy", Vector2.ZERO, _state.npcs.villagers)
	_state.npcs.add(_boy)
	var sheets := DataFile.read_sections(VillagerRules.DEFAULT_PATH)
	sheets["boy"]["romance"] = true
	_villagers = VillagerRules.new(sheets)


func test_nobody_is_open_to_romance_in_the_data() -> void:
	var rules := VillagerRules.default_rules()
	for id in rules.ids():
		assert_false(rules.is_romance_open(id), id)


func test_only_the_top_level_may_court() -> void:
	for level in range(1, FriendshipRules.LEVEL_COUNT + 1):
		_boy.opinion = _friendship.first_point_of(level)
		assert_eq(Benefits.may_court(_boy, _villagers), level == 10, "level %d" % level)


func test_a_sheet_that_does_not_allow_romance_never_may() -> void:
	_boy.opinion = _friendship.first_point_of(10)

	assert_false(Benefits.may_court(_boy))


func test_a_villager_with_a_bond_may_not_be_courted() -> void:
	_boy.opinion = _friendship.first_point_of(10)
	_boy.bond = &"courting"

	assert_false(Benefits.may_court(_boy, _villagers))


func test_a_made_up_villager_is_never_open() -> void:
	var stranger := Npc.create(5, Vector2.ZERO, _state.npcs.rules)
	stranger.opinion = _friendship.first_point_of(10)

	assert_false(Benefits.may_court(stranger, _villagers))


func test_a_romance_that_is_no_true_or_false_is_a_problem() -> void:
	var sheets := DataFile.read_sections(VillagerRules.DEFAULT_PATH)
	sheets["boy"]["romance"] = "yes"

	assert_eq(VillagerRules.new(sheets).problems().size(), 1)


func test_the_console_shows_the_bond_and_whether_courting_may_start() -> void:
	var console := Console.new(_state)
	_boy.opinion = _friendship.first_point_of(10)
	assert_eq(
		console.run("opinion boy"), ["Boy Boysen: Heart's friend, level 10 (900 points), bond none"]
	)
	_boy.bond = &"courting"
	assert_string_contains(console.run("opinion boy")[0], "bond courting")
