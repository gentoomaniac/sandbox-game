class_name FieldTarget
extends ActivityTarget
## The nearest tilled tile or field of the village.


func kind() -> String:
	return "field"


func is_searched() -> bool:
	return true
