class_name VillageSheet
extends RefCounted
## The village every villager knows, read from data/village.cfg (see there for what each key
## means): its places, people, prices, news and calendar, one topic per section, told to the
## language model in full or cut down (see NpcPrompt).

const DEFAULT_PATH := "res://data/village.cfg"

static var _default: VillageSheet

## {topic: {title, full, short}}, as in the file.
var _topics: Dictionary


func _init(topics: Dictionary) -> void:
	_topics = topics


## The sheet of the data file, loaded the first time it is asked for.
static func default_sheet() -> VillageSheet:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> VillageSheet:
	var sheet := VillageSheet.new(DataFile.read_sections(path))
	for problem in sheet.problems():
		push_error("%s: %s" % [path, problem])
	return sheet


## What is missing or wrong, as "[topic] what": each topic has a title, a `full` list of at least
## one sentence and a `short` one, which may be empty.
func problems() -> Array[String]:
	var found: Array[String] = []
	if _topics.is_empty():
		found.append("no topics")
	for topic: String in _topics:
		var values: Dictionary = _topics[topic]
		if not values.get("title") is String or values["title"].is_empty():
			found.append("[%s] title is not a text" % topic)
		if not _is_texts(values.get("full")) or values["full"].is_empty():
			found.append("[%s] full is not a list of at least one text" % topic)
		if not _is_texts(values.get("short")):
			found.append("[%s] short is not a list of texts" % topic)
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The sheet as it is told, a line for each topic with its title: "Places: The church stands on
## the highest Warft ...". `full` for all of it, else the cut-down, without the topics that have
## none.
func text(full: bool) -> String:
	var lines: Array[String] = []
	for topic: String in _topics:
		var sentences: Array = _topics[topic]["full" if full else "short"]
		if not sentences.is_empty():
			lines.append("%s: %s" % [_topics[topic]["title"], " ".join(sentences)])
	return "\n".join(lines)


static func _is_texts(value: Variant) -> bool:
	return value is Array and value.all(func(text: Variant) -> bool: return text is String)
