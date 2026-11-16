class_name CartScreen
extends Modal
## The player's sales cart over the game (design/economy/README.md, "The player's stall"): a row
## for each of its slots with the goods in it, their price in Schilling with [-] and [+] to change
## it (never below 1) and [Take back]; above them [Put] puts the stack in hand on the cart, and
## below the till, [Take] empties it into the purse. The game stands still while it is open. E and
## Escape close it. The rules are SalesCart's: the screen only shows them.

const GAP := 4
const PRICE_STEP := 1

var _cart: SalesCart
var _player: PlayerState
var _put_button := Button.new()
var _rows := VBoxContainer.new()
var _till_label := Label.new()
var _take_button := Button.new()


func _init() -> void:
	super()
	pauses_game = true
	close_actions = [&"interact"]
	var column := VBoxContainer.new()
	var title := Label.new()
	title.text = "Your cart. Villagers come by and buy what they need."
	column.add_child(title)
	_put_button.focus_mode = Control.FOCUS_NONE
	_put_button.pressed.connect(_on_put_pressed)
	column.add_child(_put_button)
	column.add_child(_scrolling(_rows))
	var till_row := HBoxContainer.new()
	till_row.add_child(_till_label)
	_take_button.focus_mode = Control.FOCUS_NONE
	_take_button.text = "Take"
	_take_button.pressed.connect(_on_take_pressed)
	till_row.add_child(_take_button)
	column.add_child(till_row)
	_panel.add_child(column)


## Opens the cart `object` (a placed sales cart) for the player. Opening it again starts afresh.
func open_cart(object: WorldObject, player: PlayerState) -> void:
	close()
	_cart = SalesCart.new(object)
	_player = player
	open()


func _on_open() -> void:
	_cart.slots().changed.connect(_refresh)
	_player.inventory.changed.connect(_refresh)
	_player.purse.changed.connect(_refresh)
	_refresh()


func _on_close() -> void:
	_cart.slots().changed.disconnect(_refresh)
	_player.inventory.changed.disconnect(_refresh)
	_player.purse.changed.disconnect(_refresh)


## Puts the stack in hand on the cart.
func put_held() -> void:
	_cart.stock(_player.inventory, _player.inventory.selected_slot)


## Changes the price of the stack in `slot` by `delta` Schilling, never below 1.
func step_price(slot: int, delta: int) -> void:
	_cart.set_price(slot, maxi(_cart.price_of(slot) + delta, 1))
	_refresh()


## Takes the stack in `slot` back into the bag.
func take_back(slot: int) -> void:
	_cart.take_back(_player.inventory, slot)


## Empties the till into the purse.
func take_takings() -> void:
	_cart.take_takings(_player.purse)
	_refresh()


func _on_put_pressed() -> void:
	put_held()


func _on_take_pressed() -> void:
	take_takings()


func _refresh() -> void:
	var held := _player.inventory.held_item()
	var can_put := held != ItemTypes.NONE and Prices.default_prices().has_worth(held)
	_put_button.disabled = not can_put
	_put_button.text = (
		"Put %s on the cart" % ItemTypes.TYPES[held]["name"]
		if can_put
		else "Hold something to put on the cart"
	)
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for slot in _cart.slots().slots.size():
		if _cart.is_for_sale(slot):
			_rows.add_child(_row_of(slot))
	_till_label.text = "In the till: %d ß " % _cart.till()
	_take_button.disabled = _cart.till() == 0


func _row_of(slot: int) -> HBoxContainer:
	var item := _cart.slots().item_in(slot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	var icon := ItemIcon.new()
	icon.show_item(item)
	row.add_child(icon)
	var label := Label.new()
	label.text = "%s x%d" % [ItemTypes.TYPES[item]["name"], _cart.slots().slots[slot]["count"]]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var minus := _button("-", step_price.bind(slot, -PRICE_STEP))
	minus.disabled = _cart.price_of(slot) <= 1
	row.add_child(minus)
	var price := Label.new()
	price.text = "%d ß" % _cart.price_of(slot)
	row.add_child(price)
	row.add_child(_button("+", step_price.bind(slot, PRICE_STEP)))
	row.add_child(_button("Take back", take_back.bind(slot)))
	return row


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	# Space is the game's use key: a focused button would take it.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button
