extends ConsoleCommand


func name() -> String:
	return "shop"


func usage() -> String:
	return "shop [restock]"


func help() -> String:
	return "Open the trade with the shopkeeper, in or out of hours; restock fills her stock."


func argument_kinds() -> Array[StringName]:
	return [&"shop_action"]


func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.size() > 1 or (arguments.size() == 1 and arguments[0] != "restock"):
		return wrong_usage()
	var rules := ShopRules.default_rules()
	var shop := rules.shop_ids()[0]
	if arguments.size() == 1:
		context.state.shops.fill(shop)
		return ["The shop is full again"]
	var keeper := context.state.npcs.find(rules.keeper_of(shop))
	if keeper == null:
		return ["No keeper in this world: spawn npc %s" % rules.keeper_of(shop)]
	if not context.shop_opener.is_valid():
		return ["No trade screen here"]
	context.shop_opener.call(keeper)
	return ["Trading with %s" % keeper.name]
