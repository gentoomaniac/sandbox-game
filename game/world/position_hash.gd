class_name PositionHash
extends RefCounted
## A stable integer hash of a tile position, for anything that must come out the same on
## every machine and Godot version (generation, variant picks). Godot's hash() is not
## documented as stable, so it is not used for that.

const MASK := 0xFFFFFFFF


## A non-negative 32-bit value from a position and a salt (e.g. the seed plus an offset, to
## keep different uses independent).
static func of(pos: Vector2i, salt := 0) -> int:
	var h := salt & MASK
	h = ((h ^ (pos.x & MASK)) * 0x9E3779B1) & MASK
	h ^= h >> 15
	h = ((h ^ (pos.y & MASK)) * 0x85EBCA6B) & MASK
	h ^= h >> 13
	h = (h * 0xC2B2AE35) & MASK
	return h ^ (h >> 16)


## Whether a tile succeeds at something that has `chance` (0 to 1) of working there, for the
## same salt always the same answer. Resolution is 1 in 100.
static func rolls(pos: Vector2i, salt: int, chance: float) -> bool:
	return of(pos, salt) % 100 < chance * 100
