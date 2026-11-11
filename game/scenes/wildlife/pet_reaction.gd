class_name PetReaction
extends Sprite2D
## The heart or the anger mark over the head of a petted animal (see Livestock `pet`): it floats up
## and fades, then frees itself. Its position is where its bottom middle starts.

const PATHS := {
	Livestock.PetShows.HEART: "res://assets/effects/pet_heart.png",
	Livestock.PetShows.ANNOYED: "res://assets/effects/pet_annoyed.png",
}
const SECONDS := 1.6
## How far it rises, in art pixels.
const RISE := 14.0


func _init(shows: Livestock.PetShows) -> void:
	texture = load(ArtSet.path(PATHS[shows]))
	offset.y = -texture.get_height() / 2.0
	# Over the animals beside it.
	z_index = 1


func _ready() -> void:
	var float_up := create_tween().set_parallel()
	float_up.tween_property(self, "position:y", position.y - RISE, SECONDS)
	float_up.tween_property(self, "modulate:a", 0.0, SECONDS).set_ease(Tween.EASE_IN)
	float_up.chain().tween_callback(queue_free)
