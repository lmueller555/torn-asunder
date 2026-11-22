extends RefCounted
## Stock Mara launch contract. Absence, explicit false, or an invalid setting
## keeps the original overworld. Both presenters use the same canonical save.
const SWITCH := "torn_asunder/mara_3d_overworld"
const TITLE := "res://game/title_screen.tscn"
const TITLE_SCRIPT := "res://game/title_screen.gd"
const FALLBACK_MESSAGE := "3D overworld unavailable. Using the original campaign map."
const SECTOR_TITLE := "res://game/overworld/mara_sector_playtest_title.tscn"
const MARCHES := "res://assets/overworld/marches/"
const MOONWASH := "res://assets/overworld/moonwash/"
const REQUIRED := {
	"PackedScene": ["res://game/overworld/moonwash/coast_renderer.tscn",
		MARCHES+"marches-corridor.glb", MARCHES+"marches-camp.glb", MARCHES+"greyhollow-mine.glb",
		MARCHES+"marches-copse-near.glb", MARCHES+"marches-copse-regional.glb",
		MARCHES+"camp/marches-road-camp-fit.glb", MARCHES+"camp/marches-road-camp-fit-regional.glb",
		MARCHES+"crossing/crossing.glb", MARCHES+"crossing/seed-mill.glb", MARCHES+"crossing/crossing-scenic-rims.scn",
		MOONWASH+"moonwash-coast.glb", MOONWASH+"moonwash-harbor-near.scn",
		MOONWASH+"moonwash-harbor-regional.glb", MOONWASH+"moonwash-shoulder-returns.glb"],
	"Texture2D": [MARCHES+"detail/marches-surface-detail.png", MARCHES+"crossing/bank-masks.jpg",
		MARCHES+"crossing/tributary-water-no-ford.jpg", MARCHES+"crossing/horizon-pigment.jpg",
		MARCHES+"crossing/south-water-pigment.jpg", MARCHES+"crossing/north-water-pigment.jpg"],
	"Shader": [MARCHES+"detail/marches_surface.gdshader", MARCHES+"crossing/tributary.gdshader",
		MARCHES+"crossing/crossing-ground.gdshader", MARCHES+"crossing/crossing-bank.gdshader",
		MARCHES+"crossing/softened-vista.gdshader"],
	"Curve3D": [MARCHES+"crossing/marches-road-to-crossing.tres"],
	"ArrayMesh": [MARCHES+"crossing/south-softened-vista.res"],
	"Resource": [MOONWASH+"moonwash-sector-data.tres"],
}
const CAMP := Vector3(-240, 21, 115)
const MINE := Vector3(0, 36, -70)
const ROAD := Vector3(248, 22.3, 32)
const CROSSING := Vector3(827, 10.6, -57)


static func requested() -> bool:
	var enabled: Variant = ProjectSettings.get_setting(SWITCH, false)
	return enabled is bool and enabled


## Never writes the profile. Not the campaign progression/intermission gate.
static func package_issue() -> String:
	var anchors_data: Variant = _read_json(MARCHES+"anchors.json")
	if not anchors_data is Dictionary or not anchors_data.get("anchors") is Dictionary \
			or not anchors_data.get("routes") is Array:
		return "The Marches route data is missing or invalid."
	var anchors: Dictionary = anchors_data.anchors
	if _vec(anchors.get("marches_camp")) != CAMP or _vec(anchors.get("year_one_mine")) != MINE \
			or _vec(anchors.get("marches_road")) != ROAD or anchors_data.routes.size() != 2:
		return "The Marches route anchors are incomplete."
	var links := {}
	for row: Variant in anchors_data.routes:
		if not row is Dictionary:
			return "The Marches route data is invalid."
		var keys := str(row.get("start", "")) + "/" + str(row.get("end", ""))
		if keys in links or keys not in ["marches_camp/year_one_mine", "year_one_mine/marches_road"] \
				or not _route(row.get("points"), _vec(anchors.get(row.start)), _vec(anchors.get(row.end))):
			return "The Marches route data is invalid."
		links[keys] = true
	var spur: Variant = _read_json(MARCHES+"camp/spur.json")
	if not spur is Dictionary or not _route(spur.get("points"), ROAD, Vector3.INF, 47):
		return "The Marches Road Camp spur data is missing or invalid."
	for kind: String in REQUIRED:
		for path: String in REQUIRED[kind]:
			if not ResourceLoader.exists(path, kind):
				return "The authored asset pack is incomplete: " + path
			var resource := ResourceLoader.load(path, kind)
			if resource == null or not resource.is_class(kind) \
					or (resource is PackedScene and not resource.can_instantiate()):
				return "The authored asset pack could not load: " + path
			if resource is Curve3D and (resource.point_count != 265
				or resource.get_point_position(0) != ROAD or resource.get_point_position(264) != CROSSING):
				return "The Crossing route is invalid."
			if path.ends_with("moonwash-sector-data.tres") and (not resource.has_method("valid_thickets")
				or not resource.call("valid_thickets") or resource.call("world_points").size() != 334):
				return "The Moonwash approach data is invalid."
	return ""


static func _route(rows: Variant, start: Vector3, finish: Vector3, count := 0) -> bool:
	if not rows is Array or rows.size() < 2 or (count > 0 and rows.size() != count):
		return false
	var first := _vec(rows[0])
	var last := _vec(rows[-1])
	if not first.is_equal_approx(start) or not last.is_finite() or (finish.is_finite() and not last.is_equal_approx(finish)):
		return false
	var length := 0.0
	var prev := first
	for row: Variant in rows:
		var this := _vec(row)
		if not this.is_finite():
			return false
		length += this.distance_to(prev)
		prev = this
	return length > 0.0


static func _vec(row: Variant) -> Vector3:
	if not row is Array or row.size() != 3:
		return Vector3.INF
	for value: Variant in row:
		if not (value is int or value is float) or not is_finite(float(value)):
			return Vector3.INF
	return Vector3(row[0], row[1], row[2])

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var decoder := JSON.new()
	return decoder.data if decoder.parse(FileAccess.get_file_as_string(path)) == OK else null
