class_name Appearance
extends RefCounted
## What the player's character wears: an ordered list of layers, each `{slot, variant}`.
## The list order is the draw order, bottom first. Every layer is drawn from the sheet
## assets/character/<slot>_<variant>.png, so a new look needs a new sheet and no code.

const BODY := &"body"
const LEGS := &"legs"
const CLOTHES := &"clothes"
const HAIR := &"hair"
const HELD := &"held"

const SHEET_PATH := "res://assets/character/%s_%s.png"

## What a new character wears, bottom layer first.
const DEFAULT_LOOK := [
	[BODY, "0"],
	[LEGS, "0"],
	[CLOTHES, "0"],
	[HAIR, "0"],
	[HELD, "hoe"],
]

## Slots that are drawn behind everything else while the character faces that way: a tool
## held in the hand is hidden by the body when the character looks away.
const BEHIND_WHEN_FACING := {Vector2i.UP: [HELD]}

## The layers in draw order. Each is `{slot: StringName, variant: String}`.
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


## Wears `variant` in `slot`: replaces what is worn there, or adds a layer on top.
func wear(slot: StringName, variant: String) -> void:
	for layer in layers:
		if layer.slot == slot:
			layer.variant = variant
			return
	layers.append({slot = slot, variant = variant})


## Takes off whatever is worn in `slot`.
func take_off(slot: StringName) -> void:
	layers = layers.filter(func(layer: Dictionary) -> bool: return layer.slot != slot)


## The sheet that holds a layer's frames.
static func sheet_path(layer: Dictionary) -> String:
	return SHEET_PATH % [layer.slot, layer.variant]
