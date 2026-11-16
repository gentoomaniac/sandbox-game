class_name QuestKinds
extends RefCounted
## The kinds of objective and of prerequisite a quest can have. Each kind is one script in a folder
## of its own, loaded by KindFolder; a new kind is a new file there and no other code.

const OBJECTIVES_DIR := "res://game/state/quests/objectives"
const CONDITIONS_DIR := "res://game/state/quests/conditions"
