class_name ActivityStep
extends RefCounted
## Where one villager has been sent for the entry of their day that is on (or is about to be): the
## place, how they stand there, and what became of the way (ActivityUpkeep). `Npc.current_step` is
## the one they were sent to last; it is not saved.

## The activity (ActivityRules) and the minute of the day its entry starts at, which together say
## which entry it is. "" and -1 for the yard of their home between entries.
var activity: String
var minute: int
## Why they stay at home instead of going: "rain" or "dark" while the activity needs it dry or
## light; "" otherwise.
var shelter := ""
## No way was found for too long: they stay at home for the rest of the entry.
var is_given_up := false
## The spot (the middle of a tile), ActivityPlaces.NOWHERE if there is none for this villager.
var spot := ActivityPlaces.NOWHERE
## The building they go into when they are at the spot, or null: the spot is the yard in front of
## its door (`inside` of data/activities.cfg).
var building: Building
## How they stand there: "stand", "walk_about" or "work", within `radius` tiles of the spot (0 for
## the radius of their anchor, see NpcRules `anchor_radius`).
var doing := "walk_about"
var radius := 0.0
## The game minutes (see GameClock `total_minutes`) at which the entry starts and at which they are
## to leave for it, for a step that is still to come.
var starts_at := 0
var leaves_at := 0
## Where they leave from and how long the walk is estimated to take, in game minutes.
var from_spot := Vector2.ZERO
var walk_minutes := 0.0
## The game minute at which the way was found blocked, or -1.
var blocked_since := -1
## Whether they are there: the anchor is the spot.
var is_arrived := false


func _init(step_activity := "", entry_minute := -1) -> void:
	activity = step_activity
	minute = entry_minute


## Whether it is for the same entry and the same shelter as `other`.
func is_same_as(other: ActivityStep) -> bool:
	return matches(other.activity, other.minute, other.shelter)


## Whether it is for this entry and this shelter.
func matches(entry_activity: String, entry_minute: int, entry_shelter: String) -> bool:
	return activity == entry_activity and minute == entry_minute and shelter == entry_shelter


## The same entry and place, with none of what has happened on the way.
func copy() -> ActivityStep:
	var step := ActivityStep.new(activity, minute)
	step.spot = spot
	step.building = building
	step.doing = doing
	step.radius = radius
	step.starts_at = starts_at
	step.leaves_at = leaves_at
	step.from_spot = from_spot
	step.walk_minutes = walk_minutes
	return step


func tile() -> Vector2i:
	return Vector2i(spot.floor())


func has_place() -> bool:
	return spot != ActivityPlaces.NOWHERE
