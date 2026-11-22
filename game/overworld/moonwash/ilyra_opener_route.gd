extends RefCounted
## Private survey of the canonical Moonwash ground mesh, not a new art package.
## Camp footprint lies inland near the existing causeway approach. The branch
## joins the measured public coast line; it never remaps or aliases Mara's Road.

const Coast := preload("res://game/overworld/moonwash/coast_route.gd")
const CAMP := "moonwash_camp"
const HARBOR := "moonwash_harbor"
const CLEAR := "ilyra_moonwash_rescue"
const JOIN_INDEX := 153
const PACE := 34.0
const CAMP_SPUR := [
	Vector3(1247.0, 34.46831, 12.0),
	Vector3(1248.0, 34.42471, 11.25),
	Vector3(1249.0, 34.3624, 10.5),
	Vector3(1250.0, 34.27255, 9.75),
	Vector3(1251.0, 34.12572, 9.0),
	Vector3(1252.2, 33.9411, 8.399994),
	Vector3(1253.4, 33.83014, 7.800003),
	Vector3(1254.6, 33.6516, 7.199997),
	Vector3(1255.8, 33.47914, 6.600006),
	Vector3(1257.0, 33.34821, 6.0),
	Vector3(1258.0, 33.21503, 5.399994),
	Vector3(1259.0, 33.1797, 4.800003),
	Vector3(1260.0, 33.14442, 4.199997),
	Vector3(1261.0, 33.1467, 3.600006),
	Vector3(1262.0, 33.15437, 3.0),
	Vector3(1262.833, 33.17677, 2.166672),
	Vector3(1263.667, 33.12814, 1.333328),
	Vector3(1264.5, 33.0643, 0.5),
	Vector3(1265.333, 32.97267, -0.333328),
	Vector3(1266.167, 32.8806, -1.166672),
	Vector3(1267.0, 32.7626, -2.0),
	Vector3(1267.6, 32.59186, -3.199997),
	Vector3(1268.2, 32.41914, -4.399994),
	Vector3(1268.8, 32.24242, -5.600006),
	Vector3(1269.4, 32.06229, -6.800003),
	Vector3(1270.0, 31.92674, -8.0),
	Vector3(1270.8, 31.77139, -8.800003),
	Vector3(1271.6, 31.66066, -9.600006),
	Vector3(1272.4, 31.58144, -10.39999),
	Vector3(1273.2, 31.52437, -11.2),
	Vector3(1274.0, 31.48399, -12.0),
	Vector3(1274.79, 31.4557, -12.68924),
]


static func points() -> PackedVector3Array:
	var road := Coast.points()
	if road.size() != 334 or not road[JOIN_INDEX].is_equal_approx(Vector3(1275.581, 31.4296, -13.37849)):
		return PackedVector3Array()
	var result := PackedVector3Array(CAMP_SPUR)
	result.append_array(road.slice(JOIN_INDEX))
	return result
