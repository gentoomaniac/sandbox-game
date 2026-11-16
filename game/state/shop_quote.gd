class_name ShopQuote
extends RefCounted
## What a deal with a shop comes to (see Shops `quote`): what the player would get costs `price`
## Schilling, what they would give is worth `value`, and `problem` says in words why it can't be
## done, or is "" when it can. The difference is paid in coin: `player_pays` is what the player
## adds from the purse when the value is less than the price, `she_pays` what the shopkeeper
## pays the player when it is more. There is no change and no coin is kept back.

var price := 0
var value := 0
var problem := ""
var player_pays := 0
var she_pays := 0


func is_fair() -> bool:
	return problem == ""
