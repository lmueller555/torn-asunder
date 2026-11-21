extends RefCounted
## Authored placement and optional approach spur. Story eligibility stays in the campaign model.

const ROAD_ID := "marches_road"
const CAMP_ID := "marches_road_camp"
const MOUNT := Vector3(287.0,21.226664,50.0)
const ASSETS := "res://assets/overworld/marches/camp/"


static func route() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"spur.json"))
	if not data is Dictionary or data.get("start","") != ROAD_ID or data.get("end","") != CAMP_ID:
		return pts
	var raw: Variant = data.get("points",[])
	if not raw is Array or raw.size()<2:
		return pts
	for row: Variant in raw:
		if not row is Array or row.size()!=3:
			return PackedVector3Array()
		for value: Variant in row:
			if not (value is float or value is int):
				return PackedVector3Array()
		var p := Vector3(float(row[0]),float(row[1]),float(row[2]))
		if not p.is_finite():
			return PackedVector3Array()
		pts.append(p)
	return pts
