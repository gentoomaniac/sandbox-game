extends GutTest
## No chain of barter deals makes goods out of nothing: whatever a player trades through two or
## three villagers, at any friendship, the goods they end with are worth no more than the goods they
## started with (Barter values both sides at the plain worth).

const START_COUNT := 12

var _state: GameState
var _rules := BarterRules.default_rules()
var _prices := Prices.default_prices()
var _barter := Barter.new()
var _villagers := {}


func before_each() -> void:
	_state = GameFactory.new_game(7)
	for id in VillagerRules.default_rules().ids():
		if _rules.has(id):
			var npc := Npc.create_villager(id, Vector2.ZERO, _state.npcs.villagers)
			npc.opinion = FriendshipRules.default_rules().first_point_of(10)
			_villagers[id] = npc


## The most the player gets of `item_got` from `villager` for `count` of `item_given`: the largest
## number the game accepts as a fair deal.
func _most_got(villager: String, item_given: StringName, count: int, item_got: StringName) -> int:
	var bag := ItemSlots.new(8)
	bag.add(item_given, count)
	var most := 0
	for got in range(1, 400):
		var deal := _barter.quote(_villagers[villager], {item_got: got}, {item_given: count}, bag)
		if deal.problem == "":
			most = got
		elif not deal.problem.begins_with("Short") and not deal.problem.begins_with("A deal"):
			break
	return most


func _worth(item: StringName, count: int) -> int:
	return _prices.worth(item) * count


func test_one_deal_never_gives_more_worth_than_it_takes() -> void:
	for id: String in _villagers:
		for given in _rules.wants(id):
			for got in _rules.offers(id):
				var most := _most_got(id, given, START_COUNT, got)
				assert_lte(
					_worth(got, most), _worth(given, START_COUNT), "%s %s for %s" % [id, given, got]
				)


func test_a_loop_between_two_villagers_never_returns_more_than_it_started_with() -> void:
	for first: String in _villagers:
		for second: String in _villagers:
			for start in _rules.wants(first):
				for middle in _rules.offers(first):
					if not _rules.wants(second).has(middle):
						continue
					var middle_count := _most_got(first, start, START_COUNT, middle)
					if middle_count == 0:
						continue
					for back in _rules.offers(second):
						var back_count := _most_got(second, middle, middle_count, back)
						assert_lte(
							_worth(back, back_count),
							_worth(start, START_COUNT),
							"%s then %s: %s, %s, %s" % [first, second, start, middle, back]
						)
