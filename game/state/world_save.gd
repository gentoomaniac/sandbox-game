class_name WorldSave
extends RefCounted
## The save data of a world: what `World.snapshot` copied, made into the JSON types. It touches
## nothing of the world, so a worker thread may do it while the game goes on.


## The save data of a `snapshot`. Safe to call from a thread.
static func dict_of(snapshot_data: Dictionary) -> Dictionary:
	var terrain_edits: Array[Array] = []
	var terrain_edits_made: Dictionary = snapshot_data["terrain_edits"]
	for pos: Vector2i in terrain_edits_made:
		terrain_edits.append(
			SaveCodec.vector_to_json(pos) + [SaveCodec.terrain_to_json(terrain_edits_made[pos])]
		)
	# A removed object is saved as `{"pos": [x, y], "object": null}`.
	var object_edits: Array[Dictionary] = []
	var object_edit_positions: Array = snapshot_data["object_edit_positions"]
	var object_edits_made: Array = snapshot_data["object_edits"]
	for index in object_edit_positions.size():
		(
			object_edits
			. append(
				{
					"pos": SaveCodec.vector_to_json(object_edit_positions[index]),
					"object": object_edits_made[index],
				}
			)
		)
	var clay_spots_data: Array[Array] = []
	var spent_clay_spots: Dictionary = snapshot_data["spent_clay_spots"]
	for pos: Vector2i in spent_clay_spots:
		clay_spots_data.append(SaveCodec.vector_to_json(pos) + [spent_clay_spots[pos]])
	var wear_data: Array[Array] = []
	var wear: Dictionary = snapshot_data["wear"]
	for pos: Vector2i in wear:
		wear_data.append(SaveCodec.vector_to_json(pos) + [wear[pos]])
	var wear_today_data: Array[Array] = []
	var wear_today: Dictionary = snapshot_data["wear_today"]
	for pos: Vector2i in wear_today:
		wear_today_data.append(SaveCodec.vector_to_json(pos) + [wear_today[pos]])
	return {
		"seed": snapshot_data["seed"],
		"ground_items": GroundItems.array_of(snapshot_data["ground_items"]),
		"spent_clay_spots": clay_spots_data,
		"wear": wear_data,
		"wear_today": wear_today_data,
		"terrain_edits": terrain_edits,
		"soil_moisture": SoilMoisture.array_of(snapshot_data["soil_moisture"]),
		"fallow_nights": snapshot_data["fallow_nights"],
		"fallow_soil": FallowSoil.array_of(snapshot_data["fallow_soil"]),
		"object_edits": object_edits,
		"buildings": snapshot_data["buildings"],
		"village": snapshot_data["village"],
	}
