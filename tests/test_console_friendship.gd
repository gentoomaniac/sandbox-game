extends ResourceCase
## The console's `friendship` command: it shows the friendship of the animal nearest to the player
## that can be petted, and sets it (task 173).

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func _animal_beside_player(species := LivestockRules.COW) -> FarmAnimal:
	var animal := FarmAnimal.new(species, &"angler", _state.player.position + Vector2(1.0, 0.0))
	_state.livestock.add(animal)
	return animal


func test_it_shows_the_friendship_of_the_animal_nearby() -> void:
	var cow := _animal_beside_player()
	cow.friendship = 40
	cow.last_petted_day = 7

	assert_eq(
		_console.run("friendship"),
		["cow: friendship 40 of 100, last petted day 7"] as Array[String]
	)


func test_it_says_never_for_an_animal_nobody_petted() -> void:
	_animal_beside_player()

	assert_eq(
		_console.run("friendship"), ["cow: friendship 0 of 100, last petted never"] as Array[String]
	)


func test_it_sets_the_friendship_up_to_a_hundred() -> void:
	var cow := _animal_beside_player()

	_console.run("friendship 55")
	assert_eq(cow.friendship, 55)

	_console.run("friendship 500")
	assert_eq(cow.friendship, 100)


func test_it_needs_an_animal_that_can_be_petted_near() -> void:
	assert_eq(
		_console.run("friendship"), ["No animal that can be petted near you"] as Array[String]
	)
	_animal_beside_player(LivestockRules.COW).position += Vector2(10.0, 0.0)
	assert_eq(
		_console.run("friendship"), ["No animal that can be petted near you"] as Array[String]
	)


func test_a_bad_value_shows_the_usage() -> void:
	_animal_beside_player()

	for line in ["friendship -3", "friendship many", "friendship 1 2"]:
		assert_eq(_console.run(line), ["Usage: friendship [0..100]"] as Array[String], line)
