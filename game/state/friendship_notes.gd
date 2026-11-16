class_name FriendshipNotes
extends RefCounted
## What the player is shown when a villager's opinion of them moves (design/villagers/
## relationships.md, "Shown in the game"): a heart when it rises, a grey cloud when it falls, and a
## line when it crosses into another level ("Antje now thinks of you as a good neighbour"), up or
## down.
## It looks at the villagers now and then (`check`) and tells what changed since the last time,
## whoever moved it (a gift, a deed, a story, the console); a villager seen the first time, or a
## loaded game's, tells nothing. Plain state: the scene only draws what it says.

## The opinion of `npc` rose (`is_gain`) or fell, for a heart or a cloud over their head.
signal moved(npc: Npc, is_gain: bool)
## The opinion of `npc` crossed into another level: the line to show.
signal level_crossed(npc: Npc, text: String)

var _npcs: Npcs
## {villager: the opinion they had when last looked at}.
var _seen := {}


func _init(npcs: Npcs) -> void:
	_npcs = npcs


## Looks at every villager and tells what moved since the last look.
func check() -> void:
	var friendship := FriendshipRules.default_rules()
	for npc in _npcs.all():
		var before: Variant = _seen.get(npc)
		_seen[npc] = npc.opinion
		if before == null or before == npc.opinion:
			continue
		moved.emit(npc, npc.opinion > before)
		var level_before := friendship.level_of(before)
		var level := friendship.level_of(npc.opinion)
		if level != level_before:
			level_crossed.emit(npc, line_for(npc, level))


## "Antje now thinks of you as a good neighbour." (the template is [notice] of data/friendship.cfg)
static func line_for(npc: Npc, level: int) -> String:
	var friendship := FriendshipRules.default_rules()
	var level_name := friendship.level_name(level).to_lower()
	var template: String = friendship.value("notice", "crossed")
	var article := "an" if level_name[0] in "aeiou" else "a"
	var words := {"first_name": npc.name.get_slice(" ", 0), "article": article, "level": level_name}
	return template.format(words)
