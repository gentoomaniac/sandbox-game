extends GutTest
## Views that show a model of the game (a world, an inventory, a player) are told again or told
## another: showing the same one twice connects once, another one either lets go of the old one
## or is refused before anything changes.


func _connections_to(model_signal: Signal, receiver: Object) -> int:
	return (
		model_signal
		. get_connections()
		. filter(func(c: Dictionary) -> bool: return c["callable"].get_object() == receiver)
		. size()
	)


func test_the_world_view_shown_the_same_world_twice_connects_once() -> void:
	var view: WorldView = add_child_autofree(WorldView.new())
	var world := World.new(1)
	view.show_world(world)
	var count := _connections_to(world.tile_changed, view)
	view.show_world(world)
	assert_eq(count, 1)
	assert_eq(_connections_to(world.tile_changed, view), count)


func test_the_world_view_refuses_another_world_and_stays_on_the_first() -> void:
	var view: WorldView = add_child_autofree(WorldView.new())
	var first := World.new(1)
	var second := World.new(2)
	view.show_world(first)
	view.show_world(second)
	assert_push_error_count(1)
	assert_eq(view.world, first)
	assert_eq(_connections_to(second.tile_changed, view), 0)
	assert_eq(_connections_to(first.tile_changed, view), 1)


func test_the_ground_item_view_refuses_another_world_and_connects_once() -> void:
	var view: GroundItemView = add_child_autofree(GroundItemView.new())
	var entities: Node2D = add_child_autofree(Node2D.new())
	var first := World.new(1)
	var second := World.new(2)
	view.show_items(first, entities)
	view.show_items(first, entities)
	assert_eq(_connections_to(first.ground_items.added, view), 1)
	view.show_items(second, entities)
	assert_push_error_count(1)
	assert_eq(_connections_to(second.ground_items.added, view), 0)


func test_the_hotbar_lets_go_of_the_old_inventory() -> void:
	var hotbar: HotbarHud = add_child_autofree(HotbarHud.new())
	var first := Inventory.new()
	var second := Inventory.new()
	hotbar.show_inventory(first)
	hotbar.show_inventory(first)
	assert_eq(_connections_to(first.changed, hotbar), 1)
	hotbar.show_inventory(second)
	assert_eq(_connections_to(first.changed, hotbar), 0)
	assert_eq(_connections_to(second.changed, hotbar), 1)


func test_the_character_screen_lets_go_of_the_old_player() -> void:
	var hotbar: HotbarHud = add_child_autofree(HotbarHud.new())
	var screen: CharacterScreen = add_child_autofree(CharacterScreen.new(hotbar))
	var first := PlayerState.new()
	var second := PlayerState.new()
	screen.show_player(first)
	screen.show_player(first)
	assert_eq(_connections_to(first.inventory.changed, screen), 1)
	assert_eq(_connections_to(get_viewport().size_changed, screen), 1)
	screen.show_player(second)
	assert_eq(_connections_to(first.inventory.changed, screen), 0)
	assert_eq(_connections_to(first.equipment.changed, screen), 0)
	assert_eq(_connections_to(first.skills.changed, screen._skills_panel), 0)
	assert_eq(_connections_to(second.skills.changed, screen._skills_panel), 1)
	assert_eq(_connections_to(second.inventory.changed, screen), 1)
	assert_eq(_connections_to(get_viewport().size_changed, screen), 1)


func test_the_crafting_screen_lets_go_of_the_old_game() -> void:
	var screen: CraftingScreen = add_child_autofree(CraftingScreen.new())
	var first := GameState.new_game(1)
	var second := GameState.new_game(2)
	screen.show_crafting(Crafting.new(first), first.player.inventory)
	screen.show_crafting(Crafting.new(second), second.player.inventory)
	assert_eq(_connections_to(first.player.inventory.changed, screen), 0)
	assert_eq(_connections_to(first.player.skills.changed, screen), 0)
	assert_eq(_connections_to(second.player.inventory.changed, screen), 1)
