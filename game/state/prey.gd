class_name Prey
extends RefCounted
## A mouse as the cats of Livestock know it: where it is and whether it is still about. The mice
## are ambient wildlife, drawn and moved by the WildlifeView and not saved; each reports itself
## here while it lives (see Mouse `sync_prey`) and Livestock decides what the cats do about it.
## What a hunt comes to is left in `fate` for the mouse to show.

enum Fate { NONE, CAUGHT, SCARED }

## Where its feet are, in tiles of the world.
var position := Vector2.ZERO
## False once it is gone from the world (run off, caught, or its view is freed): no cat hunts it.
var is_about := true
## What a cat's hunt made of it, until the mouse has shown it.
var fate := Fate.NONE
## Where the cat that scared it stood, in tiles: it runs off away from there.
var scare_point := Vector2.ZERO
