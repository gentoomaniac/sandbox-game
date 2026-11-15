class_name ConsoleContext
extends RefCounted
## What the console's commands work on: the game state, the commands themselves (for `help`) and the
## hooks the game scene sets for what the console, plain logic, cannot reach.

var state: GameState
## Every loaded command, in the order `help` lists them; set by the console.
var commands: Array[ConsoleCommand] = []

## Puts animals in view: takes a kind and a count, returns how many it placed. Set by the game
## scene, which has the animals.
var wildlife_spawner := Callable()
## Takes the wild animals of a kind away: takes a kind, returns how many it took. Set by the game
## scene, as the spawner is.
var wildlife_clearer := Callable()

## The names of the pieces `play` takes: returns an Array[String]. Set by the game scene, which
## finds the music.
var music_tracks := Callable()
## Starts a piece of music: takes its name (one of `music_tracks`), returns the line to show.
var music_player := Callable()
## Fades the music out.
var music_stopper := Callable()

## Opens the world map, or closes it when it is open: returns the line to show. Set by the game
## scene, which has the map screen.
var map_toggler := Callable()

## Has the model plan a villager's rest of the day: takes them, returns what to say (set by main).
var replanner := Callable()


func _init(game_state: GameState) -> void:
	state = game_state


## The command this word runs, or null.
func command_named(word: String) -> ConsoleCommand:
	for command in commands:
		if command.name() == word:
			return command
	return null
