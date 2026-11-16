class_name TradeScreen
extends Modal
## The trade with a shopkeeper over the game (design/economy/shop.md): what she sells on the left,
## each with its price and what is left of it, what she takes on the right, each with its value
## and the room she has for it today, and a count to change with [-] and [+] on every row. Below,
## what the player gets and gives, the purse, a line that says what is right or wrong with the
## deal (the difference of price and value is paid in coin, by the player or by her), and
## [Cover it] (the cheapest of the bag, until the goods are paid beyond the purse), [Trade] (on
## only when the deal is fair) and [Talk] (the chat with her). The game stands still while it is
## open. Rows with nothing to trade are grey. The numbers and the refusals are Shops': the screen
## only shows them. E and Escape close it, as the chest's. The console's `nocost` makes the goods
## free.

## The player wants to talk to the keeper instead.
signal talk_requested(keeper: Npc)

const PANEL_GAP := 16
const DONE_NOTE := "Done."

## What the player gets and gives, each item to count: the counts of the rows.
var want := {}
var give := {}

var _state: GameState
var _keeper: Npc
## How the keeper treats the player by their friendship.
var _standing := ShopStanding.new()
var _shop := ""
var _quote: ShopQuote
## What the line below says instead of the quote's, after a trade.
var _note := ""
var _sell_rows: Array[TradeRow] = []
var _take_rows: Array[TradeRow] = []
var _title_label := Label.new()
var _hint_label := Label.new()
var _sells_column := VBoxContainer.new()
var _takes_column := VBoxContainer.new()
var _get_label := Label.new()
var _give_label := Label.new()
var _purse_label := Label.new()
var _status_label := Label.new()
var _cover_button := Button.new()
var _trade_button := Button.new()
var _talk_button := Button.new()


func _init() -> void:
	super()
	pauses_game = true
	close_actions = [&"interact"]
	var column := VBoxContainer.new()
	for label in [_title_label, _hint_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	var goods := HBoxContainer.new()
	goods.add_theme_constant_override("separation", PANEL_GAP)
	goods.add_child(_goods_column("She sells", _sells_column))
	goods.add_child(_goods_column("She takes", _takes_column))
	column.add_child(goods)
	for label in [_get_label, _give_label, _purse_label, _status_label]:
		column.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	for button: Button in [_cover_button, _trade_button, _talk_button]:
		# Space is the game's use key: a focused button would take it.
		button.focus_mode = Control.FOCUS_NONE
		buttons.add_child(button)
	_cover_button.text = "Cover it"
	_trade_button.text = "Trade"
	_talk_button.text = "Talk"
	_cover_button.pressed.connect(cover)
	_trade_button.pressed.connect(trade)
	_talk_button.pressed.connect(func() -> void: talk_requested.emit(_keeper))
	column.add_child(buttons)
	_panel.add_child(column)


## Opens the shop of `keeper`, who is a shopkeeper (the rules have a shop of theirs), with the
## player's bag of `state`. Opening it again starts afresh.
func open_shop(keeper: Npc, state: GameState) -> void:
	close()
	_state = state
	_keeper = keeper
	_standing = ShopStanding.with_keeper(keeper)
	if state.cheats.is_cost_off:
		_standing.price_percent = 0
	_shop = ShopRules.default_rules().shop_of_keeper(keeper.id)
	assert(_shop != "", "%s keeps no shop" % keeper.id)
	_show_goods()
	open()


func _on_open() -> void:
	want = {}
	give = {}
	_note = ""
	_title_label.text = "%s, %s" % [_keeper.name, _keeper.trade]
	_hint_label.text = "Prices are in Schilling (ß)."
	_state.player.inventory.changed.connect(_refresh)
	_state.player.purse.changed.connect(_refresh)
	_refresh()


func _on_close() -> void:
	_state.player.inventory.changed.disconnect(_refresh)
	_state.player.purse.changed.disconnect(_refresh)


## What the player gets, plus one of the item (or less one).
func step_want(item: StringName, delta: int) -> void:
	var most := _state.shops.stock_of(_shop, item)
	_set_count(want, item, clampi(want.get(item, 0) + delta, 0, most))


## What the player gives, plus one of the item (or less one): never more than they carry or than
## she has room for today.
func step_give(item: StringName, delta: int) -> void:
	_set_count(give, item, clampi(give.get(item, 0) + delta, 0, _most_to_give(item)))


## Fills what the player gives with the cheapest of the bag, until what they get is paid.
func cover() -> void:
	give = _state.shops.cover(_shop, want, _state.player.inventory, _standing, _state.player.purse)
	_note = ""
	_refresh()


## Does the deal if it is fair.
func trade() -> void:
	var problem := _state.shops.trade(
		_shop, want, give, _state.player.inventory, _standing, _state.player.purse
	)
	if problem == "":
		want = {}
		give = {}
		_note = DONE_NOTE
	_refresh()


## What the line below the lists says now.
func status_text() -> String:
	if _note != "":
		return _note
	if not _quote.is_fair():
		return _quote.problem
	if _quote.she_pays > 0:
		return "She pays you %d ß." % _quote.she_pays
	if _quote.player_pays > 0:
		return "You pay %d ß." % _quote.player_pays
	return "A fair trade."


func is_trade_enabled() -> bool:
	return _quote.is_fair()


func _goods_column(title: String, rows_holder: VBoxContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	var header := Label.new()
	header.text = title
	column.add_child(header)
	column.add_child(_scrolling(rows_holder))
	return column


## Makes the rows of what this shop sells and takes.
func _show_goods() -> void:
	var rules := ShopRules.default_rules()
	for row in _sell_rows + _take_rows:
		row.free()
	_sell_rows.clear()
	_take_rows.clear()
	for item in rules.sold(_shop):
		_sell_rows.append(_new_row(item, _sells_column, step_want))
	for item in rules.taken(_shop):
		_take_rows.append(_new_row(item, _takes_column, step_give))


func _new_row(item: StringName, holder: VBoxContainer, on_step: Callable) -> TradeRow:
	var row := TradeRow.new(item)
	row.stepped.connect(func(delta: int) -> void: on_step.call(item, delta))
	holder.add_child(row)
	return row


func _most_to_give(item: StringName) -> int:
	return mini(_state.player.inventory.count_of(item), _state.shops.room_of(_shop, item))


func _set_count(counts: Dictionary, item: StringName, count: int) -> void:
	if count == 0:
		counts.erase(item)
	else:
		counts[item] = count
	_note = ""
	_refresh()


func _refresh() -> void:
	var shops := _state.shops
	var bag := _state.player.inventory
	for row in _sell_rows:
		var stock := shops.stock_of(_shop, row.item)
		var price := shops.price_of(_shop, row.item, _standing)
		var detail := "%d ß, %d left" % [price, stock]
		row.show_state(detail, want.get(row.item, 0), want.get(row.item, 0) < stock, stock == 0)
	for row in _take_rows:
		var room := shops.room_of(_shop, row.item)
		var carried := bag.count_of(row.item)
		var detail := (
			"%d ß, room %d, you have %d" % [shops.value_of(_shop, row.item), room, carried]
		)
		var can_add: bool = give.get(row.item, 0) < _most_to_give(row.item)
		row.show_state(detail, give.get(row.item, 0), can_add, carried == 0 or room == 0)
	_quote = shops.quote(_shop, want, give, bag, _standing, _state.player.purse)
	_get_label.text = "You get: %s" % _counts_text(want, _quote.price)
	_give_label.text = "You give: %s" % _counts_text(give, _quote.value)
	_purse_label.text = "Your purse: %d ß" % _state.player.purse.schilling
	_status_label.text = status_text()
	_cover_button.disabled = want.is_empty()
	_trade_button.disabled = not _quote.is_fair()


## "5 Turnip seeds (15 ß)", or "nothing".
static func _counts_text(counts: Dictionary, worth: int) -> String:
	if counts.is_empty():
		return "nothing"
	var parts: Array[String] = []
	for item: StringName in counts:
		parts.append("%d %s" % [counts[item], ItemTypes.TYPES[item]["name"]])
	return "%s (%d ß)" % [", ".join(parts), worth]
