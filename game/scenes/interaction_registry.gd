class_name InteractionRegistry
extends RefCounted
## What each kind of E (Interaction.Kind) is called in the hint over the hotbar and does in the game
## scene. The domain decides which kind applies (see Interaction `choice_at`); a feature of the
## scene registers the words and the opening of its own kind, so neither the hint nor the interact
## flow lists the kinds. A kind nobody registered says nothing and does nothing.

var _labels := {}
var _openers := {}


## Registers `kind`: `label` is its words in the hint, a String or a Callable that takes the
## choice's subject and returns one; `open` is called with the subject when E is pressed.
## A kind is owned by one feature: a second registration is an error and is refused, so the first
## stays.
func register(kind: Interaction.Kind, label: Variant, open: Callable) -> void:
	if _openers.has(kind):
		push_error(
			(
				"InteractionRegistry: %s is registered by %s, and again by %s"
				% [Interaction.Kind.find_key(kind), _owner_of(_openers[kind]), _owner_of(open)]
			)
		)
		return
	_labels[kind] = label
	_openers[kind] = open


func _owner_of(open: Callable) -> String:
	var owner: Object = open.get_object()
	if owner == null:
		return "nobody"
	var script: Script = owner.get_script()
	if script == null or script.get_global_name() == &"":
		return owner.get_class()
	return script.get_global_name()


func is_registered(kind: Interaction.Kind) -> bool:
	return _openers.has(kind)


## What E does with the choice, as "Talk to Antje", or "".
func label_of(choice: Interaction.Choice) -> String:
	var label: Variant = _labels.get(choice.kind, "")
	return label.call(choice.subject) if label is Callable else label


## What E does on `target`, as "Talk to Antje", or "". Asks the rules that do it, so the hint can't
## differ from the action.
func e_text(state: GameState, target: Vector2i) -> String:
	return label_of(Interaction.choice_at(state, target))


func open(choice: Interaction.Choice) -> void:
	if _openers.has(choice.kind):
		_openers[choice.kind].call(choice.subject)
