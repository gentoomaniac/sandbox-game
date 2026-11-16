extends GutTest
## The coins of the village (design/economy/README.md, "Lore"): the game has only the Schilling, so
## no sheet or line of speech may name another coin, and the prices the village sheet names are
## those of the shop.

const SHEET_FILES: Array[String] = [
	"res://data/village.cfg", "res://data/villagers.cfg", "res://data/npcs.cfg"
]
const SHOP := "trienke"


func test_no_sheet_or_speech_names_a_coin_the_game_lacks() -> void:
	var coin := RegEx.create_from_string("\\b(Mark|Reichstaler|Pfennig)\\b")
	for path in SHEET_FILES:
		var found := coin.search(FileAccess.get_file_as_string(path))
		assert_null(found, "%s names a coin the game lacks" % path)


func test_the_prices_of_the_village_sheet_are_those_of_the_shop() -> void:
	var rules := ShopRules.default_rules()
	var shop_values := DataFile.read_sections(ShopRules.DEFAULT_PATH)
	var bread: int = shop_values["shop.%s.takes.%s" % [SHOP, ItemTypes.BREAD]]["worth"]
	var egg: int = shop_values["shop.%s.takes.%s" % [SHOP, ItemTypes.EGG]]["worth"]
	var candle := rules.worth_of_sold(SHOP, ItemTypes.CANDLE)
	var sheet := VillageSheet.default_sheet()
	var told := sheet.text(true, ["money"] as Array[String])

	assert_string_contains(
		told,
		(
			"A loaf of rye bread is worth %d Schilling, an egg %d and a candle %d; "
			% [bread, egg, candle]
		)
	)
	var price := rules.price(SHOP, ItemTypes.CANDLE)
	assert_string_contains(told, "the candle costs %d Schilling" % price)
