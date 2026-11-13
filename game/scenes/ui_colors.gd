class_name UiColors
extends RefCounted
## The colors the screens share.

## Palette color ink (see tools/art/palette.py), see-through: dims the world behind a screen.
const BACKDROP := Color(0.114, 0.106, 0.149, 0.6)
## The palette's ember, behind a message about something that went wrong.
const ERROR_PLATE := Color("a8402e")
## The palette's cream and ink (see tools/art/palette.py): the plate and the text of a villager's
## speech bubble, which must read over any ground.
const SPEECH_FILL := Color("f1e6c2")
const SPEECH_INK := Color("1d1b26")
