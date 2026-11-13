class_name MemoryWeight
extends RefCounted
## How much a memory or a story weighs for the villager who has it (design/villagers/gossip.md,
## Memory): a full long-term memory forgets the lightest first. Saved as the word.

enum { LOW, MEDIUM, HIGH }

const WORDS: Array[String] = ["low", "medium", "high"]


static func to_word(weight: int) -> String:
	return WORDS[weight]


## The weight of a saved word (SaveValidator has checked it).
static func from_word(word: String) -> int:
	return WORDS.find(word)
