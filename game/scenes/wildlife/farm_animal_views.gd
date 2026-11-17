class_name FarmAnimalViews
extends Node
## The farm animals of the game's Livestock, which are state and saved, shown in the view of the
## wildlife: one FarmAnimalView each while it is near the view (in the ring or within it), looked
## at every tick like the wild animals. WildlifeView owns it, connects it to the Livestock and has
## it follow the view.

## The views shown, by the animal they show.
var views: Dictionary[FarmAnimal, FarmAnimalView] = {}
var _wildlife: WildlifeView


func _init(wildlife: WildlifeView) -> void:
	_wildlife = wildlife


## Gives a farm animal its view if it has none and is in the ring around the view or within it.
func show_if_near(animal: FarmAnimal) -> void:
	if views.has(animal):
		return
	var near := _wildlife.view_rect().grow(
		_wildlife.rules.general("spawn_margin_tiles") * WildlifeRules.TILE_SIZE
	)
	if not near.has_point(animal.position * WildlifeRules.TILE_SIZE):
		return
	var animal_view := FarmAnimalView.new(animal)
	animal_view.wildlife = _wildlife
	views[animal] = animal_view
	_wildlife.world_view.entities.add_child(animal_view)
	_wildlife.animal_added.emit(animal_view)


## Shows the farm animals of `livestock` that came near the view, and takes away those far from it.
func follow(livestock: Livestock) -> void:
	var view := _wildlife.view_rect()
	for animal: FarmAnimal in views.keys():
		if _wildlife.rules.is_beyond_view(views[animal].position, view):
			views[animal].queue_free()
			views.erase(animal)
	for animal in livestock.all():
		show_if_near(animal)


## Takes every view away (the player went indoors).
func clear() -> void:
	for animal_view in views.values():
		animal_view.queue_free()
	views.clear()


## Frees the view of an animal that left the world, if it has one.
func free_view(animal: FarmAnimal) -> void:
	if views.has(animal):
		views[animal].queue_free()
		views.erase(animal)


## Lets the heart or the anger mark rise over a petted animal, if it is in view.
func show_pet_reaction(animal: FarmAnimal, shows: Livestock.PetShows) -> void:
	if views.has(animal):
		views[animal].show_pet_reaction(shows)
