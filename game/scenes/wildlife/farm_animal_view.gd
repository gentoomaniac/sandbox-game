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

## Where the top of each species' head is, as measured on its sheets (idle, graze and sleep frames):
## in pixels in front of its feet toward the way it faces, and up from them. For standing (and
## walking and running), grazing (the head down) and asleep, in that order. What a heart or the
## anger mark rises over.
const HEADS := {
	LivestockRules.COW: [Vector2(26, 39), Vector2(21, 24), Vector2(26, 27)],
	LivestockRules.PIG: [Vector2(13, 22), Vector2(13, 18), Vector2(13, 15)],
	LivestockRules.SHEEP: [Vector2(14, 26), Vector2(11, 22), Vector2(14, 20)],
	LivestockRules.CHICKEN: [Vector2(7, 24), Vector2(7, 18), Vector2(6, 19)],
	LivestockRules.RABBIT: [Vector2(5, 20), Vector2(7, 11), Vector2(7, 12)],
	LivestockRules.DOG: [Vector2(17, 36), Vector2(16, 24), Vector2(17, 19)],
	LivestockRules.CAT: [Vector2(12, 24), Vector2(12, 18), Vector2(12, 16)],
	LivestockRules.HORSE: [Vector2(29, 75), Vector2(22, 51), Vector2(29, 50)],
}
## The pixels between a head and what rises over it.
const HEAD_GAP := 2

var farm_animal: FarmAnimal
## The activity it shows, to start the frames of a new one only when it changes.
var _activity := -1


## The sheet that shows the animal: that of its species and look, with the saddle on for a
## saddled horse (see tools/art/livestock.py).
static func sheet_kind(animal: FarmAnimal) -> StringName:
	var kind := "%s_%s" % [animal.species, animal.look]
	return StringName(kind + "_saddled" if animal.is_saddled else kind)


## Its friendship is its FarmAnimal's, not the wild animals' of this kind's name (a rabbit).
func has_friendship() -> bool:
	return false


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


## A heart or the anger mark rises over its head (see Livestock `petted`), standing on it.
func show_pet_reaction(shows: Livestock.PetShows) -> void:
	var poses: Array = HEADS[farm_animal.species]
	var pose := 0
	if farm_animal.activity == FarmAnimal.Activity.SLEEP:
		pose = 2
	elif farm_animal.activity == FarmAnimal.Activity.GRAZE:
		pose = 1
	var head: Vector2 = poses[pose]
	var reaction := PetReaction.new(shows)
	reaction.position = Vector2(head.x * farm_animal.facing, -head.y - HEAD_GAP)
	add_child(reaction)


## Rounded to whole art pixels, so the animal stays put on the world as the camera moves.
func _pixel_position() -> Vector2:
	return (farm_animal.position * TerrainTileset.TILE_SIZE).round()
