class_name FarmAnimalView
extends Animal
## A farm animal (FarmAnimal) on screen. Unlike the wild animals it decides nothing itself:
## Livestock moves it and says what it does, and this shows it there, playing the frames of what
## it does. The WildlifeView makes one while the animal is near the view.
##
## A cat hunts the mice of the view, which are wild animals and not state: when it picks what to
## do next it looks for one (`WildlifeView.nearest_animal`, as a stork for its frogs), and this
## tells Livestock where the mouse is while it crouches and creeps up. As it pounces the catch is
## drawn: the mouse sees it coming and dashes off, or is caught where the cat lands.

## The row of its sheet that each activity plays (see tools/art/livestock.py), and how fast.
const ACTIONS := {
	FarmAnimal.Activity.IDLE: [&"idle", 1.5],
	FarmAnimal.Activity.WALK: [&"walk", 5.0],
	FarmAnimal.Activity.GRAZE: [&"graze", 2.0],
	FarmAnimal.Activity.RUN: [&"run", 10.0],
	FarmAnimal.Activity.FLEE: [&"run", 12.0],
	FarmAnimal.Activity.SLEEP: [&"sleep", 0.5],
	FarmAnimal.Activity.CROUCH: [&"crouch", 1.5],
	FarmAnimal.Activity.CREEP: [&"creep", 3.0],
	FarmAnimal.Activity.POUNCE: [&"pounce", 9.0],
}
## Half the width of each species' contact shadow, from its hind feet to its front ones, in
## pixels: the farm animals are drawn at 32 px per tile (Animal `art_scale` 1).
const SHADOW_HALF_WIDTHS := {
	LivestockRules.COW: 19,
	LivestockRules.SHEEP: 12,
	LivestockRules.CHICKEN: 6,
	LivestockRules.RABBIT: 7,
	LivestockRules.DOG: 12,
	LivestockRules.CAT: 8,
	LivestockRules.HORSE: 22,
}

var farm_animal: FarmAnimal
## The activity it shows, to start the frames of a new one only when it changes.
var _activity := -1
## The mouse a cat hunts, or null.
var _prey: Mouse


## The sheet that shows the animal: that of its species and look, with the saddle on for a
## saddled horse (see tools/art/livestock.py).
static func sheet_kind(animal: FarmAnimal) -> StringName:
	var kind := "%s_%s" % [animal.species, animal.look]
	return StringName(kind + "_saddled" if animal.is_saddled else kind)


func _init(animal: FarmAnimal) -> void:
	super(animal.species, sheet_kind(animal))
	farm_animal = animal
	shadow_half_width = SHADOW_HALF_WIDTHS[animal.species]
	art_scale = 1
	position = _pixel_position()


func _ready() -> void:
	super()
	_sprite.self_modulate = farm_animal.tint


func _update(_delta: float) -> void:
	# A ridden horse is drawn under its rider (see PlayerView).
	visible = not farm_animal.is_ridden
	position = _pixel_position()
	# Saddling a horse, or taking its saddle off, changes its sheet; the frames stay as they are.
	if sheet_kind(farm_animal) != _sheet_kind:
		_sheet_kind = sheet_kind(farm_animal)
		_sprite.texture = load(WildlifeSprites.SHEET_PATH % _sheet_kind)

	_face(farm_animal.facing)
	if _prey != null:
		_follow_prey()
	if farm_animal.activity == _activity:
		return
	var last_activity := _activity
	_activity = farm_animal.activity
	is_asleep = _activity == FarmAnimal.Activity.SLEEP
	var action: Array = ACTIONS[_activity]
	_play(action[0], action[1])
	# Its state (see Animal) is the activity's name: running off is `flee`, as for a wild rabbit.
	_enter(StringName(FarmAnimal.Activity.find_key(_activity).to_lower()))
	if farm_animal.species == LivestockRules.CAT:
		_hunt(last_activity)


## What a cat's hunt comes to when it does something new: as it pounces the mouse dashes off,
## unless the catch roll goes the cat's way; once it has landed the mouse is caught if it is still
## under it; done hunting, it looks for the next mouse.
func _hunt(last_activity: int) -> void:
	var livestock := wildlife.livestock()
	match farm_animal.activity:
		FarmAnimal.Activity.CROUCH, FarmAnimal.Activity.CREEP:
			return
		FarmAnimal.Activity.POUNCE:
			if _prey != null and wildlife.rng.randf() >= livestock.rules.hunting("catch_chance"):
				_prey.flee_from(position)
				_prey = null
			return
	var catch_reach := livestock.rules.hunting("catch_tiles") * WildlifeRules.TILE_SIZE
	if (
		last_activity == FarmAnimal.Activity.POUNCE
		and _has_prey()
		and _prey.position.distance_to(position) <= catch_reach
	):
		_prey.is_done = true
	_prey = null
	if livestock.can_hunt(farm_animal):
		var sight := livestock.rules.hunting("sight_tiles") * WildlifeRules.TILE_SIZE
		_prey = wildlife.nearest_animal(WildlifeRules.MOUSE, position, sight) as Mouse
		if _prey != null:
			livestock.start_hunt(farm_animal, _prey.position / WildlifeRules.TILE_SIZE)


## Tells Livestock where the mouse is, or that it is gone (run from the player, or into cover).
func _follow_prey() -> void:
	if _has_prey():
		wildlife.livestock().track_prey(farm_animal, _prey.position / WildlifeRules.TILE_SIZE)
	else:
		_prey = null
		wildlife.livestock().stop_hunt(farm_animal)


## Whether its mouse is still about: not caught, not gone (the view frees what is done).
func _has_prey() -> bool:
	return is_instance_valid(_prey) and not _prey.is_done


## Rounded to whole art pixels, so the animal stays put on the world as the camera moves.
func _pixel_position() -> Vector2:
	return (farm_animal.position * TerrainTileset.TILE_SIZE).round()
