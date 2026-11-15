extends ActivityCase
## A shopkeeper who thinks ill of the player (levels 1 and 2) does not trade: E speaks to them, they
## say they have nothing to sell, and a model is told the stall is shut.

const THURSDAY := DAY
const STALL_TILE_X := 30

var _trienke: Npc
var _friendship := FriendshipRules.default_rules()


func before_each() -> void:
	super()
	_build_warm_road()
	_trienke = _resident("trienke")
	_trienke.workplace = Workplace.of_spot("the market stall", _road_tile(STALL_TILE_X))
	_set_time(THURSDAY, 8)
	_trienke.position = _trienke.workplace.spot()
	_trienke.anchor = _trienke.position
	_state.player.position = _trienke.position + Vector2(0, 1)
	_pass_minutes(1)


func _choice() -> Interaction.Choice:
	return Interaction.choice_at(_state, _trienke.tile())


func test_a_keeper_at_stranger_or_better_trades() -> void:
	for level in [3, 4, 10]:
		_trienke.opinion = _friendship.first_point_of(level)
		assert_eq(_choice().kind, Interaction.Kind.TRADE, "level %d" % level)
	assert_eq(ShopHours.closed_line(_state, _trienke), "")


func test_a_keeper_at_level_1_or_2_does_not_trade() -> void:
	for level in [1, 2]:
		_trienke.opinion = _friendship.first_point_of(level)
		assert_true(ShopHours.is_open(_state, _trienke), "her hours are not the player's")
		assert_eq(_choice().kind, Interaction.Kind.CHAT, "level %d" % level)
		assert_eq(
			ShopHours.closed_line(_state, _trienke),
			NpcTalkRules.default_rules().value("shop", "refused")
		)
		assert_false(ShopHours.fact(_state, _trienke)["is_open"])
