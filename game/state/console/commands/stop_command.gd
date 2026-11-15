extends ConsoleCommand


func name() -> String:
	return "stop"


func usage() -> String:
	return "stop"


func help() -> String:
	return "Fade the music out."


func run(_arguments: PackedStringArray) -> Array[String]:
	if not context.music_stopper.is_valid():
		return [ConsoleHelper.NO_MUSIC]
	context.music_stopper.call()
	return ["Music fading out"]
