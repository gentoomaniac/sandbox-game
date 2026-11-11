extends WildlifeCase
## Taking the animals of a species out of the world: Livestock forgets them and their views go.

var _livestock: Livestock
## A view wired up as the game does (show_wildlife), to see that it follows the livestock.
var _shown: WildlifeView


func before_each() -> void:
	super()
	_livestock = _state.livestock
	_shown = WildlifeView.new()
	add_child_autofree(_shown)
	_shown.show_wildlife(_state, _wildlife.world_view, _camera)


func _add_animal(species: StringName, feet := Vector2(2.5, 9.5)) -> FarmAnimal:
	var animal := FarmAnimal.create(species, 1, feet, _livestock.rules)
	_livestock.add(animal)
	return animal


func test_every_animal_of_the_species_goes_and_the_others_stay() -> void:
	_add_animal(LivestockRules.COW)
	_add_animal(LivestockRules.COW)
	var sheep := _add_animal(LivestockRules.SHEEP)
	assert_eq(_livestock.remove_species(LivestockRules.COW), 2)
	assert_eq(_livestock.all(), [sheep] as Array[FarmAnimal])
	assert_eq(_livestock.remove_species(LivestockRules.COW), 0)


func test_the_removed_are_not_in_the_next_save() -> void:
	_add_animal(LivestockRules.DOG)
	_add_animal(LivestockRules.CAT)
	_livestock.remove_species(LivestockRules.DOG)
	var data := _livestock.to_array()
	assert_eq(data.size(), 1)
	assert_eq(data[0]["species"], String(LivestockRules.CAT))


func test_the_views_of_the_removed_are_freed() -> void:
	var cow := _add_animal(LivestockRules.COW)
	var sheep := _add_animal(LivestockRules.SHEEP)
	var cow_view: FarmAnimalView = _shown._farm_animals[cow]
	_livestock.remove_species(LivestockRules.COW)
	assert_true(cow_view.is_queued_for_deletion())
	assert_false(_shown._farm_animals.has(cow))
	assert_true(_shown._farm_animals.has(sheep))
