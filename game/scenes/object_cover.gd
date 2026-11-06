class_name ObjectCover
extends Sprite2D
## The cover of a bed in the world (the bedroll's blanket), drawn over the player lying in it so
## that only their head shows. The beds of houses have theirs in InteriorView. The picture is a
## cell of the objects atlas, the bed's own cell cut down (see the art generator), so it sits
## where the bed's cell does.

var _bed: WorldObject


func _init() -> void:
	z_index = PlayerView.COVER_Z_INDEX
	visible = false


## Shows the cover of `bed`, or nothing for null or a bed without one.
func cover(bed: WorldObject) -> void:
	if bed == _bed:
		return
	_bed = bed
	var path: String = "" if bed == null else bed.type_data().get("object_cover", "")
	visible = path != ""
	if not visible:
		return
	texture = load(path)
	# The cell is centred on the footprint, its bottom edge on the footprint's.
	var tile_size := TerrainTileset.TILE_SIZE
	var footprint: Vector2i = bed.type_data()["footprint"]
	position = Vector2(
		(bed.pos.x + footprint.x / 2.0) * tile_size,
		(bed.pos.y + footprint.y) * tile_size - texture.get_height() / 2.0
	)
