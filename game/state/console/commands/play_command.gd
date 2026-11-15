extends ConsoleCommand


func name() -> String:
	return "play"


func usage() -> String:
	return "play <track>"


func help() -> String:
	return "Play a piece of music in a loop (another one crossfades), rendered first; stop ends it."


func argument_kinds() -> Array[StringName]:
	return [&"track"]


func run(arguments: PackedStringArray) -> Array[String]:
	if not context.music_player.is_valid():
		return [ConsoleHelper.NO_MUSIC]
	if arguments.size() != 1:
		var lines := wrong_usage()
		lines.append_array(ConsoleHelper.candidates_text(self, context))
		return lines
	var track := track_named(arguments[0], ConsoleHelper.candidates(&"track", context))
	if track.is_empty():
		return ConsoleHelper.unknown("track", arguments[0], self, context)
	var line: String = context.music_player.call(track)
	return [line]


## The track `word` stands for among `tracks`: the whole name, or the name without its first word
## ("tide" for "sketch_tide"); "" when there is none, or more than one.
static func track_named(word: String, tracks: Array[String]) -> String:
	var matches := tracks.filter(
		func(track: String) -> bool: return word == track or track.ends_with("_" + word)
	)
	return matches[0] if matches.size() == 1 else ""
