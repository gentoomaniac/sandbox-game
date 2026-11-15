class_name ShopStanding
extends RefCounted
## How a shopkeeper treats the player by their friendship (see Benefits): the percent of the price
## the player pays (`better_prices` brings it down) and whether the best wares are sold to them
## (`best_wares`). Shops asks for it with a deal; the default is a stranger's.

var price_percent := 100
var has_best_wares := false


## The standing of the player with `keeper`.
static func with_keeper(keeper: Npc) -> ShopStanding:
	var standing := ShopStanding.new()
	if Benefits.allows(keeper, &"better_prices"):
		standing.price_percent = FriendshipRules.default_rules().better_prices_percent()
	standing.has_best_wares = Benefits.allows(keeper, &"best_wares")
	return standing
