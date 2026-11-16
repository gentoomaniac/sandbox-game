class_name BarterScreen
extends Modal
## The barter with a villager over the game (design/economy/README.md, "Barter with villagers"):
## what they offer on the left, each with its worth, what they want on the right, each with its
## worth and how many the player carries, a count to change with [-] and [+] on every row, and
## below what the player gets and gives in Schilling worth, a line that says what is right or wrong
## with the deal, [Trade] (on only when the deal is fair) and [Talk] (back to the chat). It is
## opened from the chat (see BarterFlow). The numbers and the refusals are Barter's: the screen
## only shows them. Escape closes it.

## The player wants to talk to the villager instead.
signal talk_requested(npc: Npc)

const PANEL_GAP := 16
const DONE_NOTE := "Done."

## What the player gets and gives, each item to count: the counts of the rows.
var want := {}
var give := {}

var _state: GameState
var _npc: Npc
var _barter := Barter.new()
var _prices := Prices.default_prices()
var _quote: ShopQuote
var _note := ""
var _offer_rows: Array[TradeRow] = []
var _want_rows: Array[TradeRow] = []
var _title_label := Label.new()
var _offers_column := VBoxContainer.new()
var _wants_column := VBoxContainer.new()
var _get_label := Label.new()
var _give_label := Label.new()
var _status_label := Label.new()
var _trade_button := Button.new()
var _talk_button := Button.new()


func _init() -> void:
	super()
	pauses_game = true
	var column := VBoxContainer.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)
	var goods := HBoxContainer.new()
	goods.add_theme_constant_override("separation", PANEL_GAP)
	goods.add_child(_goods_column("They offer", _offers_column))
	goods.add_child(_goods_column("They want", _wants_column))
	column.add_child(goods)
	for label in [_get_label, _give_label, _status_label]:
		column.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	for button: Button in [_trade_button, _talk_button]:
		# Space is the game's use key: a focused button would take it.
		button.focus_mode = Control.FOCUS_NONE
		buttons.add_child(button)
	_trade_button.text = "Trade"
	_talk_button.text = "Talk"
	_trade_button.pressed.connect(trade)
	_talk_button.pressed.connect(func() -> void: talk_requested.emit(_npc))
	column.add_child(buttons)
	_panel.add_child(column)


## Opens the barter with `npc`, who barters (see Barter `is_open`), with the bag of `state`.
## Opening it again starts afresh.
func open_barter(npc: Npc, state: GameState) -> void:
	close()
	_npc = npc
	_state = state
	_show_goods()
	open()


func _on_open() -> void:
	want = {}
	give = {}
	_note = ""
	_title_label.text = "Barter with %s. Worths are in Schilling (ß)." % _npc.name
	_state.player.inventory.changed.connect(_refresh)
	_refresh()


func _on_close() -> void:
	_state.player.inventory.changed.disconnect(_refresh)


## What the player gets, plus one of the item (or less one): a good is never worth more than a
## whole deal may be.
func step_want(item: StringName, delta: int) -> void:
	var most := BarterRules.default_rules().cap() / _prices.worth(item)
	_set_count(want, item, clampi(want.get(item, 0) + delta, 0, most))


## What the player gives, plus one of the item (or less one): never more than they carry.
func step_give(item: StringName, delta: int) -> void:
	var most := _state.player.inventory.count_of(item)
	_set_count(give, item, clampi(give.get(item, 0) + delta, 0, most))


## Does the deal if it is fair.
func trade() -> void:
	var problem := _barter.trade(_state, _npc, want, give, _state.player.inventory)
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


## Makes the rows of what the villager offers and wants.
func _show_goods() -> void:
	var rules := BarterRules.default_rules()
	for row in _offer_rows + _want_rows:
		row.free()
	_offer_rows.clear()
	_want_rows.clear()
	for item in rules.offers(_npc.id):
		_offer_rows.append(_new_row(item, _offers_column, step_want))
	for item in rules.wants(_npc.id):
		_want_rows.append(_new_row(item, _wants_column, step_give))


func _new_row(item: StringName, holder: VBoxContainer, on_step: Callable) -> TradeRow:
	var row := TradeRow.new(item)
	row.stepped.connect(func(delta: int) -> void: on_step.call(item, delta))
	holder.add_child(row)
	return row


func _set_count(counts: Dictionary, item: StringName, count: int) -> void:
	if count == 0:
		counts.erase(item)
	else:
		counts[item] = count
	_note = ""
	_refresh()


func _refresh() -> void:
	var bag := _state.player.inventory
	for row in _offer_rows:
		var count: int = want.get(row.item, 0)
		var worth := _prices.worth(row.item)
		var most := BarterRules.default_rules().cap() / worth
		row.show_state("%d ß" % worth, count, count < most, false)
	for row in _want_rows:
		var count: int = give.get(row.item, 0)
		var carried := bag.count_of(row.item)
		var detail := "%d ß, you have %d" % [_prices.worth(row.item), carried]
		row.show_state(detail, count, count < carried, carried == 0)
	_quote = _barter.quote(_npc, want, give, bag)
	_get_label.text = "You get: %s" % _counts_text(want, _quote.price)
	_give_label.text = "You give: %s" % _counts_text(give, _quote.value)
	_status_label.text = status_text()
	_trade_button.disabled = not _quote.is_fair()


## "3 Egg (6 ß)", or "nothing".
static func _counts_text(counts: Dictionary, worth: int) -> String:
	if counts.is_empty():
		return "nothing"
	var parts: Array[String] = []
	for item: StringName in counts:
		parts.append("%d %s" % [counts[item], ItemTypes.TYPES[item]["name"]])
	return "%s (%d ß)" % [", ".join(parts), worth]
