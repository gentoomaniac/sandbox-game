class_name CharacterDragCase
extends DragCase
## Helpers for tests that drag stacks on the bag or the character screen, open on a new player.

const BACKPACK_SLOT := Inventory.HOTBAR_SIZE

var _player: PlayerState
var _bag: BagScreen
var _character: CharacterScreen
var _hotbar: HotbarHud


## The hotbar of the HUD and a player who wears a waistcoat, in the window.
func _make_player_and_hotbar() -> void:
	_player = PlayerState.new()
	_make_window()
	_hotbar = HotbarCase.new_hotbar()
	_window.add_child(_hotbar)
	_hotbar.show_inventory(_player.inventory)
	_window.add_child(FadeScreen.new())
	_player.equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)


## The bag open in the window, under the HUD's hotbar.
func _open_bag_screen() -> void:
	_make_player_and_hotbar()
	_bag = BagScreen.new(_hotbar)
	_window.add_child(_bag)
	_bag.show_player(_player)
	_bag.open()


## The character screen open in the window, under the HUD's hotbar.
func _open_character_screen() -> void:
	_make_player_and_hotbar()
	_character = CharacterScreen.new(_hotbar)
	_window.add_child(_character)
	_character.show_player(_player)
	_character.open()


## The bag and the character screen both open in the window, as they are side by side in the game.
func _open_both_screens() -> void:
	_make_player_and_hotbar()
	_bag = BagScreen.new(_hotbar)
	_window.add_child(_bag)
	_bag.show_player(_player)
	_character = CharacterScreen.new(_hotbar)
	_window.add_child(_character)
	_character.show_player(_player)
	_bag.open()
	_character.open()


func _backpack_view(slot: int) -> SlotView:
	return _hotbar._slot_views[slot] if slot < Inventory.HOTBAR_SIZE else _bag._backpack_views[slot]


func _equipment_view(slot: StringName) -> SlotView:
	return _character._equipment_views[slot]


func _set_stack(slot: int, item: StringName, count: int) -> void:
	_player.inventory.slots[slot] = {"item": item, "count": count}
	_player.inventory.changed.emit()


func _empty_slot(slot: int) -> void:
	_player.inventory.slots[slot] = {}
	_player.inventory.changed.emit()
