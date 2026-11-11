class_name Muffle
extends RefCounted
## How muffled the outside world sounds: 0 in the open, 1 inside a building, moving between
## the two over FADE_SECONDS so entering a house is a soft change. The audio service turns the
## amount into the cutoff of a low-pass filter and into a drop in volume.

const FADE_SECONDS := 0.4
const OPEN_CUTOFF_HZ := 20500.0
const MUFFLED_CUTOFF_HZ := 700.0

var is_inside := false
## 0 (not muffled) to 1 (fully muffled).
var amount := 0.0


## Moves the amount towards where `is_inside` wants it.
func step(delta: float) -> void:
	amount = move_toward(amount, 1.0 if is_inside else 0.0, delta / FADE_SECONDS)


## The low-pass cutoff for the amount. Pitch is heard in octaves, so it moves between the two
## ends by their ratio, not by their difference.
func cutoff_hz() -> float:
	return OPEN_CUTOFF_HZ * pow(MUFFLED_CUTOFF_HZ / OPEN_CUTOFF_HZ, amount)


## How far the volume is turned down for the amount, given the drop (negative, in dB) at full
## muffle. Decibels are heard as loudness, so it fades in them, like the cutoff in octaves.
func volume_db(muffled_db: float) -> float:
	return muffled_db * amount
