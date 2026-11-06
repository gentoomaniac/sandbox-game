class_name FarmAnimalView
extends Animal
## A farm animal (FarmAnimal) on screen. Unlike the wild animals it decides nothing itself:
## Livestock moves it and says what it does, and this shows it there, playing the frames of what
## it does. The WildlifeView makes one while the animal is near the view.

## The row of its sheet that each activity plays (see tools/art/livestock.py), and how fast.
const ACTIONS := {
	FarmAnimal.Activity.IDLE: [&"idle", 1.5],
	FarmAnimal.Activity.WALK: [&"walk", 5.0],
	FarmAnimal.Activity.GRAZE: [&"graze", 2.0],
	FarmAnimal.Activity.FLEE: [&"walk", 12.0],
	FarmAnimal.Activity.SLEEP: [&"sleep", 0.5],
}
## Half the width of each species' contact shadow, in pixels.
const SHADOW_HALF_WIDTHS := {
	LivestockRules.COW: 11,
	LivestockRules.SHEEP: 7,
	LivestockRules.CHICKEN: 3,
	LivestockRules.RABBIT: 4,
}

var farm_animal: FarmAnimal
## The activity it shows, to start the frames of a new one only when it changes.
var _activity := -1


func _init(animal: FarmAnimal) -> void:
	super(animal.species, StringName("%s_%s" % [animal.species, animal.look]))
	farm_animal = animal
	shadow_half_width = SHADOW_HALF_WIDTHS[animal.species]
	position = _pixel_position()


func _ready() -> void:
	super()
	_sprite.self_modulate = farm_animal.tint


func _update(_delta: float) -> void:
	position = _pixel_position()
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
