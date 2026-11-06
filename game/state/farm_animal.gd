class_name FarmAnimal
extends RefCounted
## One farm animal (a species of LivestockRules): which it is, how it looks, where it stands and
## what it is doing. Livestock moves it; the WildlifeView draws it while it is near the view.

enum Activity { IDLE, WALK, GRAZE, FLEE, SLEEP }

var species: StringName
## The name of its picture (see `looks` in data/livestock.cfg).
var look: StringName
## What its picture is multiplied by (see `tints`), so that no two look quite alike.
var tint := Color.WHITE
## Where its feet are, in tiles of the world.
var position: Vector2
var activity := Activity.IDLE
## Seconds left of the activity; running from the player ends by distance, and sleep by the
## clock, instead.
var seconds_left := 0.0
## The way it walks or runs, a unit vector.
var heading := Vector2.RIGHT
## The way of the last step it took: the ground under its nose that way is walkable (see Livestock
## `_walk`); zero before its first.
var last_step := Vector2.ZERO
## The way it looks: 1 to the right, -1 to the left (the pictures face right).
var facing := 1.0
## Minutes it goes to sleep and wakes later than its species does, so that a herd doesn't lie
## down all at once (see Livestock `is_sleep_time`).
var bedtime_delay := 0.0


func _init(animal_species: StringName, animal_look: StringName, feet: Vector2) -> void:
	species = animal_species
	look = animal_look
	position = feet


## A new animal of a species whose look and tint follow from `seed_value` alone: the same seed
## always gives the same animal.
static func create(
	animal_species: StringName, seed_value: int, feet: Vector2, rules: LivestockRules
) -> FarmAnimal:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var animal := FarmAnimal.new(animal_species, rules.pick_look(animal_species, rng), feet)
	animal.tint = rules.pick_tint(animal_species, rng)
	return animal


func tile() -> Vector2i:
	return Vector2i(position.floor())
