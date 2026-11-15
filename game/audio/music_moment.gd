class_name MusicMoment
extends RefCounted
## What the MusicDirector chooses the music by: the hour of the game's clock, whether the player
## is inside a building, and whether the world shows the classic art (the chiptune version of the
## music) or the 32 px art (the fuller one). Plain data. A new condition (the season, the weather)
## is a field here and a key of a piece's section in data/music.cfg that MusicRules.fits reads.

var hour := 12
var is_inside := false
var is_classic_art := false


func _init(hour_of_day := 12, is_inside_now := false, is_classic := false) -> void:
	hour = hour_of_day
	is_inside = is_inside_now
	is_classic_art = is_classic


## The moment of `state`: its clock's hour and the player's place, in the art `is_classic` or not.
static func of(state: GameState, is_classic := false) -> MusicMoment:
	return MusicMoment.new(
		state.clock.minute_of_day / GameClock.MINUTES_PER_HOUR, state.is_inside(), is_classic
	)
