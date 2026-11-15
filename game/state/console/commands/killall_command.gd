extends ConsoleCommand


func name() -> String:
	return "killall"


func usage() -> String:
	return "killall <kind> | killall npc [<id>]"


func help() -> String:
	return (
		"Remove every animal of a kind (the same kinds as spawn), or villagers (npc: those made"
		+ " up; npc <id>: one named), from the game and the save. Wild animals are not saved:"
		+ " others may come by the usual rules."
	)


func argument_kinds() -> Array[StringName]:
	return [&"animal"]


func argument_kinds_for(arguments: PackedStringArray) -> Array[StringName]:
	if not arguments.is_empty() and arguments[0] == ConsoleHelper.NPC:
		return ConsoleHelper.NPC_ARGUMENTS
	return argument_kinds()


func takes_villager_ids() -> bool:
	return true


## Takes the animals of a kind, or one villager, out of the game and the state that is saved.
## A bare `killall npc` removes the villagers made up (those with no id): the ones written by hand
## are the village's, so each needs its id. A ridden horse is not removed from under the
## player: they get off first, as the dismount needs a free spot that is theirs to choose.
func run(arguments: PackedStringArray) -> Array[String]:
	if arguments.is_empty():
		return ConsoleHelper.candidates_text(self, context)
	var word := arguments[0]
	if arguments.size() > 2 or (arguments.size() == 2 and word != ConsoleHelper.NPC):
		return wrong_usage()
	if word == ConsoleHelper.NPC and arguments.size() == 1:
		return _kill_made_up_villagers()
	if word == ConsoleHelper.NPC:
		return _kill_villager(arguments[1])
	if context.state.npcs.villagers.has(word):
		return _kill_villager(word)
	return _kill_animals(word)


func _kill_animals(word: String) -> Array[String]:
	var state := context.state
	if word == ConsoleHelper.ROOSTER:
		var roosters := state.livestock.remove_species(
			LivestockRules.CHICKEN, LivestockRules.ROOSTER_LOOK
		)
		return [_removed_text(roosters, word)]
	if LivestockRules.SPECIES.has(StringName(word)):
		var horse := state.player.horse
		if horse != null and horse.species == StringName(word):
			return ["You are riding a %s: get off first" % word]
		return [_removed_text(state.livestock.remove_species(StringName(word)), word)]
	var kind := ConsoleHelper.wildlife_kind(word)
	if not WildlifeRules.KINDS.has(kind):
		return ConsoleHelper.unknown("animal", word, self, context)
	var clearer := context.wildlife_clearer
	var cleared: int = clearer.call(kind) if clearer.is_valid() else 0
	return [_removed_text(cleared, word) + " (wild animals are not saved: more may come)"]


func _kill_made_up_villagers() -> Array[String]:
	var npcs := context.state.npcs
	var removed := 0
	var named: Array[String] = []
	for npc in npcs.all():
		if npc.id.is_empty():
			npcs.remove(npc)
			removed += 1
		else:
			named.append(npc.id)
	var line := (
		_removed_text(removed, ConsoleHelper.NPC) + " (the named villagers stay: killall npc <id>"
	)
	return [line + (", here: %s)" % ", ".join(named) if not named.is_empty() else ")")]


func _kill_villager(villager_id: String) -> Array[String]:
	var npcs := context.state.npcs
	if not npcs.villagers.has(villager_id):
		return ConsoleHelper.unknown("villager", villager_id, self, context)
	var npc := npcs.find(villager_id)
	if npc == null:
		return ["%s is not in the world" % villager_id]
	npcs.remove(npc)
	return ["Removed %s" % npc.name]


func _removed_text(count: int, word: String) -> String:
	return "Removed %d %s" % [count, word] if count > 0 else "No %s to remove" % word
