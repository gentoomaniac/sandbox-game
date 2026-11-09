class_name Builder
extends RefCounted
## What the hammer does. Holding it is build mode: `choice` is the building it would place and
## `style` its look, picked in the build menu, and `place` builds it where the player points,
## taking the materials from the inventory. Plain logic; BuildMode draws the ghost and BuildMenu
## the menu. X switches to taking down: the hammer takes down the building or the thing the
## player placed (a chest, a workbench) on a tile, and gives back what it held.
## Dismissing build mode (Escape, right click) lasts until the player holds something else, or
## selects the hammer again.

var choice: StringName = BuildingTypes.ids()[0]
## Which of the styles of `choice` it would place (see BuildingTypes `styles`).
var style := &""

var _state: GameState
var _is_dismissed := false
var _is_taking_down := false


func _init(state: GameState) -> void:
	_state = state
	_state.player.inventory.changed.connect(_on_inventory_changed)


## Whether the player is placing buildings: they hold the hammer, have not dismissed it and are
## not on horseback (no building from the saddle).
func is_building() -> bool:
	return _is_hammer_held() and not _is_dismissed and _state.player.horse == null


## Whether the hammer takes down instead of building (see `toggle_taking_down`).
func is_taking_down() -> bool:
	return is_building() and _is_taking_down


func dismiss() -> void:
	_is_dismissed = true
	_is_taking_down = false


func toggle_taking_down() -> void:
	_is_taking_down = not _is_taking_down


## Holds the hammer, if there is one on the hotbar. Returns whether the player does.
func select_hammer() -> bool:
	var inventory := _state.player.inventory
	for slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(slot) == ItemTypes.HAMMER:
			_is_dismissed = false
			inventory.select(slot)
			return true
	return false


## Moves `choice` by `step` buildings along the file's order, wrapping round, in the
## building's own style.
func pick(step: int) -> void:
	var ids := BuildingTypes.ids()
	choose(ids[posmod(ids.find(choice) + step, ids.size())])


## Chooses a building, in one of its styles.
func choose(building_type: StringName, building_style := &"") -> void:
	choice = building_type
	style = building_style


## Moves `style` by `step` along the styles of the chosen building, stopping at either end.
func pick_style(step: int) -> void:
	var styles := BuildingTypes.styles(choice)
	style = styles[clampi(styles.find(style) + step, 0, styles.size() - 1)]


## The entry of the chosen building in the chosen style (see BuildingTypes `of`).
func type_data() -> Dictionary:
	return BuildingTypes.of(choice, style)


## What the chosen building takes, item id to count.
func costs() -> Dictionary:
	return type_data()["costs"]


## What the player lacks for the chosen building, item id to the count short; empty when they
## have it all (or the cost cheat is on).
func shortfalls() -> Dictionary:
	var short := {}
	if _state.cheats.is_cost_off:
		return short
	for item: StringName in costs():
		var missing: int = costs()[item] - _state.player.inventory.count_of(item)
		if missing > 0:
			short[item] = missing
	return short


## Places the chosen building in the chosen style with its top left tile at `origin` and takes
## its materials.
## Returns it, or null if the land is blocked or something is missing.
func place(origin: Vector2i) -> Building:
	if (
		not shortfalls().is_empty()
		or not _state.world.placement_blockers(choice, origin).is_empty()
	):
		return null
	if not _state.cheats.is_cost_off:
		var is_paid := _state.player.inventory.exchange(costs(), {})
		assert(is_paid, "The shortfalls were checked, so the costs can be paid")
	var building := _state.world.place_building(choice, origin, style)
	_state.report(ActionOutcome.BUILD, origin, choice, {} if _state.cheats.is_cost_off else costs())
	return building


## What the hammer would take down on a tile, or null if there is nothing to take down.
func take_down_target(tile: Vector2i) -> TakeDownTarget:
	var building := _state.world.building_at(tile)
	if building != null:
		return TakeDownTarget.of_building(building)
	var object := _state.world.object_at(tile)
	if object != null and ItemTypes.item_placing(object.type) != &"":
		return TakeDownTarget.of_object(object)
	return null


## What taking the target down gives, item id to count: half of a building's materials, a placed
## thing whole with what it holds.
func take_down_gives(target: TakeDownTarget) -> Dictionary:
	if target.building != null:
		return _state.refund_of_building(target.building)
	return ToolUse.new(_state).items_of_placed(target.object)


## Why the target can't be taken down now, or "".
func why_not_take_down(target: TakeDownTarget) -> String:
	if target.building != null:
		return _state.why_not_take_down(target.building)
	if ToolUse.new(_state).is_standing_on(target.object):
		return "Step off it first."
	if _state.player.bed_lying_in == target.object:
		return "Get up first."
	return ""


## Takes the target down. A building's materials lie in front of its door; a placed thing goes
## to the inventory with what it holds, and what does not fit lies on the ground where it stood.
## Returns false, and does nothing, for a target that has a reason to stay.
func take_down(target: TakeDownTarget) -> bool:
	if target.building != null:
		return _state.take_down_building(target.building)
	if why_not_take_down(target) != "":
		return false
	var items := take_down_gives(target)
	_state.world.remove_object(target.object.pos)
	for item: StringName in items:
		var left := _state.player.inventory.add(item, items[item])
		if left > 0:
			_state.world.drop_items(target.object.pos, {item: left})
	_state.report(ActionOutcome.TAKE_DOWN, target.object.pos, target.object.type, items)
	return true


func _is_hammer_held() -> bool:
	var held := _state.player.inventory.held_item()
	return held != ItemTypes.NONE and ItemTypes.TYPES[held].get("tool") == ItemTypes.HAMMER


func _on_inventory_changed() -> void:
	if not _is_hammer_held():
		_is_dismissed = false
		_is_taking_down = false
