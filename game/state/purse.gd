class_name Purse
extends RefCounted
## The player's money: one whole number of Schilling (design/economy/README.md). It weighs nothing
## and never goes below 0.

signal changed

var schilling: int:
	set(value):
		assert(value >= 0, "A purse is never below 0")
		if value == schilling:
			return
		schilling = value
		changed.emit()


func _init(start := 0) -> void:
	schilling = start


func can_afford(cost: int) -> bool:
	return cost <= schilling


func add(amount: int) -> void:
	assert(amount >= 0, "Add a whole number from 0; spend to take away")
	schilling += amount


## Pays `cost`; returns false and changes nothing when the purse holds less.
func spend(cost: int) -> bool:
	assert(cost >= 0, "A cost is a whole number from 0")
	if not can_afford(cost):
		return false
	schilling -= cost
	return true
