class_name FarmAnimalView
extends Animal
## A farm animal (FarmAnimal) on screen. Unlike the wild animals it decides nothing itself:
## Livestock moves it and says what it does, and this shows it there, playing the frames of what
## it does. The WildlifeView makes one while the animal is near the view.
##
## A cat's hunt is Livestock's too: this only shows the crouch, the creep and the pounce.

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
## pixels.
const SHADOW_HALF_WIDTHS := {
	LivestockRules.COW: 19,
	LivestockRules.PIG: 14,
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


## The sheet that shows the animal: that of its species and look, with the saddle on for a
## saddled horse (see tools/art/livestock.py).
static func sheet_kind(animal: FarmAnimal) -> StringName:
	var kind := "%s_%s" % [animal.species, animal.look]
	return StringName(kind + "_saddled" if animal.is_saddled else kind)


func _init(animal: FarmAnimal) -> void:
	super(animal.species, sheet_kind(animal))
	farm_animal = animal
	shadow_half_width = SHADOW_HALF_WIDTHS[animal.species]
	position = _pixel_position()


func _ready() -> void:
	super()
	_sprite.self_modulate = farm_animal.tint


func _update(_delta: float) -> void:
	# A ridden horse is drawn under its rider (see PlayerView), a hen in a coop is not seen.
	visible = not farm_animal.is_ridden and not farm_animal.is_housed
	position = _pixel_position()
	# Saddling a horse, or taking its saddle off, changes its sheet.
	if sheet_kind(farm_animal) != _sheet_kind:
		_sheet_kind = sheet_kind(farm_animal)
		show_art_set()

	_face(farm_animal.facing)
	if farm_animal.activity == _activity:
		return
	_activity = farm_animal.activity
	is_asleep = _activity == FarmAnimal.Activity.SLEEP
	var action: Array = ACTIONS[_activity]
	_play(action[0], action[1])
	# Its state (see Animal) is the activity's name: running off is `flee`, as for a wild rabbit.
	_enter(StringName(FarmAnimal.Activity.find_key(_activity).to_lower()))


## Rounded to whole art pixels, so the animal stays put on the world as the camera moves.
func _pixel_position() -> Vector2:
	return (farm_animal.position * TerrainTileset.TILE_SIZE).round()
