class_name CharacterDragCase
extends DragCase
## Helpers for tests that drag stacks on the character screen, open on a new player.

const BACKPACK_SLOT := Inventory.HOTBAR_SIZE

var _player: PlayerState
var _screen: CharacterScreen
var _hotbar: HotbarHud


## The screen open in the window, under the HUD's hotbar, on a player who wears a waistcoat.
func _open_character_screen() -> void:
	_player = PlayerState.new()
	_make_window()
	_hotbar = HotbarCase.new_hotbar()
	_window.add_child(_hotbar)
	_hotbar.show_inventory(_player.inventory)
	_window.add_child(FadeScreen.new())
	_screen = CharacterScreen.new(_hotbar)
	_window.add_child(_screen)
	_screen.show_player(_player)
	_player.equipment.equip(Equipment.BODY, ItemTypes.WAISTCOAT)
	_screen.open()


func _backpack_view(slot: int) -> SlotView:
	return (
		_hotbar._slot_views[slot] if slot < Inventory.HOTBAR_SIZE else _screen._backpack_views[slot]
	)


func _equipment_view(slot: StringName) -> SlotView:
	return _screen._equipment_views[slot]


func _set_stack(slot: int, item: StringName, count: int) -> void:
	_player.inventory.slots[slot] = {"item": item, "count": count}
	_player.inventory.changed.emit()


func _empty_slot(slot: int) -> void:
	_player.inventory.slots[slot] = {}
	_player.inventory.changed.emit()
