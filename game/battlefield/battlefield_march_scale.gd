extends RefCounted
## Authoring scale, not a mission timer or a bounding-box measurement.

const Battle := preload("res://game/battlefield/command_battle.gd")

enum Tier { COMPACT, SMALL, STANDARD, LARGE, EXPANSIVE }

# Current authoring targets; this does not change any deployed terrain or pace.
const TARGET_SECONDS := [180.0, 220.0, 260.0, 310.0, 360.0]
# Existing field fixtures still verify the original physical journeys during migration.
const BASELINE_TARGET_SECONDS := [90.0, 110.0, 130.0, 155.0, 180.0]


## Report the nearest planning tier, even if the measured march needs resizing.
## Return -1 for invalid or absent measurements. Ties favor the smaller tier.
static func classify(seconds: float) -> int:
	return _classify(seconds, TARGET_SECONDS)


static func classify_baseline(seconds: float) -> int:
	return _classify(seconds, BASELINE_TARGET_SECONDS)


static func _classify(seconds: float, targets: Array) -> int:
	if not is_finite(seconds) or seconds <= 0.0:
		return -1
	for index in range(targets.size() - 1):
		if seconds <= (targets[index] + targets[index + 1]) * 0.5:
			return index
	return Tier.EXPANSIVE


static func within_target_band(seconds: float) -> bool:
	return is_finite(seconds) and seconds >= TARGET_SECONDS.front() and seconds <= TARGET_SECONDS.back()


static func within_baseline_band(seconds: float) -> bool:
	return is_finite(seconds) and seconds >= BASELINE_TARGET_SECONDS.front() and seconds <= BASELINE_TARGET_SECONDS.back()


## Reference budget at normal formation speed, not a substitute for measuring
## the march through the real terrain and authored route points.
static func planning_distance(tier: int) -> float:
	return TARGET_SECONDS[tier] * Battle.FORMATION_SPEED if tier >= 0 and tier < TARGET_SECONDS.size() else -1.0
