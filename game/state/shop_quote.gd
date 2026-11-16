class_name ShopQuote
extends RefCounted
## What a deal with a shop comes to (see Shops `quote`): what the player would get costs `price`
## Schilling, what they would give is worth `value`, and `problem` says in words why it can't be
## done, or is "" when it can. A fair deal that is worth more than it costs says what the shopkeeper
## keeps in `keeps`; there is no change.

var price := 0
var value := 0
var problem := ""
var keeps := 0


func is_fair() -> bool:
	return problem == ""
