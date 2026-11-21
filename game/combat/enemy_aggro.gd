extends RefCounted
## Initial proximity aggression, not attack range, minimap visibility, or pursuit leash.
const RADIUS_METRES := 50.0

## Older mission values indicate whether the author enabled proximity aggro.
## A passive group or one activated only by the script remains at zero.
static func configured(authored_radius: float) -> float:
	return RADIUS_METRES if is_finite(authored_radius) and authored_radius>0.0 else 0.0
