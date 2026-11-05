class_name Appearance
extends RefCounted
## What the player's character wears: an ordered list of layers, each `{slot, variant}`.
## Every layer is drawn from the sheet assets/character/<slot>_<variant>.png, so a new look
## needs a new sheet and no code. The body and hair are the character's own; the legs, feet,
## clothes and head layers follow what is worn (see `dress`), and the held layer the hand.

const BODY := &"body"
const LEGS := &"legs"
const FEET := &"feet"
const CLOTHES := &"clothes"
const HAIR := &"hair"
const HEAD := &"head"
const HELD := &"held"

## The draw order, bottom first. A layer in a slot that is not listed goes on top.
const DRAW_ORDER := [BODY, LEGS, FEET, CLOTHES, HAIR, HEAD, HELD]

## The layer each Equipment slot shows. Slots that are not listed (back, hands) show nothing.
const LAYER_OF_EQUIPMENT_SLOT := {
	Equipment.HEAD: HEAD,
	Equipment.BODY: CLOTHES,
	Equipment.LEGS: LEGS,
	Equipment.FEET: FEET,
}

const SHEET_PATH := "res://assets/character/%s_%s.png"

## What a new character looks like by themselves, bottom layer first.
const DEFAULT_LOOK := [[BODY, "0"], [HAIR, "0"]]

## Slots that are drawn behind everything else while the character faces that way: a tool
## held in the hand is hidden by the body when the character looks away.
const BEHIND_WHEN_FACING := {Vector2i.UP: [HELD]}

## The layers in draw order (see DRAW_ORDER). Each is `{slot: StringName, variant: String}`.
var layers: Array[Dictionary] = []


func _init() -> void:
	for slot_and_variant in DEFAULT_LOOK:
		layers.append({slot = slot_and_variant[0], variant = slot_and_variant[1]})


## The layers in the order they are drawn when the character looks along `facing`.
func layers_for(facing: Vector2i) -> Array[Dictionary]:
	var behind_slots: Array = BEHIND_WHEN_FACING.get(facing, [])
	var behind: Array[Dictionary] = []
	var in_front: Array[Dictionary] = []
	for layer in layers:
		(behind if layer.slot in behind_slots else in_front).append(layer)
	return behind + in_front


## Wears `variant` in `slot`: replaces what is worn there, or adds a layer where the slot
## belongs in the draw order.
func wear(slot: StringName, variant: String) -> void:
	for layer in layers:
		if layer.slot == slot:
			layer.variant = variant
			return
	var index := 0
	while index < layers.size() and _rank(layers[index].slot) <= _rank(slot):
		index += 1
	layers.insert(index, {slot = slot, variant = variant})


## Takes off whatever is worn in `slot`.
func take_off(slot: StringName) -> void:
	layers = layers.filter(func(layer: Dictionary) -> bool: return layer.slot != slot)


## Shows what is worn: each layer that follows the equipment gets the layer variant of the
## item in its slot, or none when the slot is empty.
func dress(equipment: Equipment) -> void:
	for equipment_slot: StringName in LAYER_OF_EQUIPMENT_SLOT:
		var item := equipment.item_in(equipment_slot)
		var layer_slot: StringName = LAYER_OF_EQUIPMENT_SLOT[equipment_slot]
		if item == ItemTypes.NONE:
			take_off(layer_slot)
		else:
			wear(layer_slot, ItemTypes.TYPES[item]["layer_variant"])


static func _rank(slot: StringName) -> int:
	var rank := DRAW_ORDER.find(slot)
	return DRAW_ORDER.size() if rank == -1 else rank


## The sheet that holds a layer's frames.
static func sheet_path(layer: Dictionary) -> String:
	return SHEET_PATH % [layer.slot, layer.variant]


func to_dict() -> Dictionary:
	var layers_data: Array[Dictionary] = []
	for layer in layers:
		layers_data.append({"slot": str(layer.slot), "variant": layer.variant})
	return {"layers": layers_data}


static func from_dict(data: Dictionary) -> Appearance:
	var appearance := Appearance.new()
	appearance.layers.clear()
	for layer: Dictionary in data["layers"]:
		appearance.layers.append({slot = StringName(layer["slot"]), variant = layer["variant"]})
	return appearance
