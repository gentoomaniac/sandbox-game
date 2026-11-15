class_name InteriorNpcViews
extends Node
## Draws the villagers who are inside the building the player is in (see `Npc.inside`): an NpcView
## for each, among the interior view's y-sorted entities, where the player stands among them. It
## looks at the villagers each frame, so one who goes in or comes out while the player is there
## appears or goes. The villagers outdoors are NpcViews'.

var _npcs: Npcs
var _entities: Node2D
## The room shown, or null while the player is out in the world.
var _room: Interior
var _views: Dictionary[Npc, NpcView] = {}


## Shows the villagers of `npcs` that are in the room shown (see `show_room`) in `entities`.
func show_npcs(npcs: Npcs, entities: Node2D) -> void:
	_npcs = npcs
	_entities = entities
	npcs.removed.connect(_free_view)


## Shows the villagers inside `room`, or none for null.
func show_room(room: Interior) -> void:
	_room = room
	_update_views()


func _process(_delta: float) -> void:
	_update_views()


func _update_views() -> void:
	for npc in _views.keys():
		if not _is_in_room(npc):
			_free_view(npc)
	if _room == null:
		return
	for npc in _npcs.all():
		if _is_in_room(npc) and not _views.has(npc):
			_views[npc] = NpcView.new(npc, true)
			_entities.add_child(_views[npc])


func _is_in_room(npc: Npc) -> bool:
	return _room != null and npc.inside != null and npc.inside.interior == _room


func _free_view(npc: Npc) -> void:
	if _views.has(npc):
		_views[npc].queue_free()
		_views.erase(npc)
