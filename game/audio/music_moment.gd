class_name MusicMoment
extends RefCounted
## What the MusicDirector chooses the music by: the hour of the game's clock and whether the player
## is inside a building. Plain data. A new condition (the season, the weather) is a field here and
## a key of a piece's section in data/music.cfg that MusicRules.fits reads.

var hour := 12
var is_inside := false


func _init(hour_of_day := 12, is_inside_now := false) -> void:
	hour = hour_of_day
	is_inside = is_inside_now


## The moment of `state`: its clock's hour and the player's place.
static func of(state: GameState) -> MusicMoment:
	return MusicMoment.new(
		state.clock.minute_of_day / GameClock.MINUTES_PER_HOUR, state.is_inside()
	)
