class_name FarmAnimal
extends RefCounted
## One farm animal (a species of LivestockRules): which it is, how it looks, where it stands and
## what it is doing. Livestock moves it; the WildlifeView draws it while it is near the view.

## A cat hunting a mouse crouches, creeps up and pounces (see Livestock `start_hunt`).
enum Activity { IDLE, WALK, GRAZE, RUN, FLEE, SLEEP, CROUCH, CREEP, POUNCE }

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
## The game minute (see GameClock `total_minutes`) until which it follows the player, as a dog
## does once given a bone; 0 for an animal that never did.
var follow_until_minute := 0
## Seconds a follower has got no nearer the player for something in its way (see Livestock).
var stuck_seconds := 0.0
## A horse wears a saddle (see ToolUse `SADDLE`): it can be ridden.
var is_saddled := false
## The player rides it (see GameState `mount`): it goes where they ride, and does nothing of its
## own accord. Not saved, as the riding isn't.
var is_ridden := false
## The mouse a hunting cat is after, or null. Not saved, as the hunt isn't (the mice are not
## either).
var hunted: Prey
## Where that mouse was when the cat last looked, in tiles of the world: a pounce lands there.
var pounce_at := Vector2.ZERO
## Seconds before a cat hunts again (see `rest_seconds` in data/livestock.cfg).
var hunt_rest_seconds := 0.0


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


## What it is doing is not saved: a loaded animal looks about for what to do next.
func to_dict() -> Dictionary:
	return {
		"species": str(species),
		"look": str(look),
		"tint": tint.to_html(false),
		"position": SaveCodec.float_vector_to_json(position),
		"follow_until_minute": follow_until_minute,
		"is_saddled": is_saddled,
	}


static func from_dict(data: Dictionary, rules: LivestockRules) -> FarmAnimal:
	var animal_species := StringName(data["species"])
	assert(
		LivestockRules.SPECIES.has(animal_species), "Unknown species in save: %s" % animal_species
	)
	assert(rules.looks(animal_species).has(data["look"]), "Unknown look in save: %s" % data["look"])
	var animal := FarmAnimal.new(
		animal_species, StringName(data["look"]), SaveCodec.float_vector_from_json(data["position"])
	)
	animal.tint = Color.html(data["tint"])
	animal.follow_until_minute = int(data["follow_until_minute"])
	animal.is_saddled = data["is_saddled"]
	return animal
