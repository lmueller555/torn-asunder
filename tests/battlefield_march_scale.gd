extends SceneTree

const Scale := preload("res://game/battlefield/battlefield_march_scale.gd")

var _failures := 0


func _initialize() -> void:
	for index in range(5):
		var seconds: float = Scale.TARGET_SECONDS[index]
		_check(Scale.classify(seconds) == index and Scale.within_target_band(seconds),
				"Each authored target maps to one supported tier.")
		_check(is_equal_approx(Scale.planning_distance(index), seconds * 3.0),
				"At the present standard march speed, the planning budgets match the target times.")
		_check(seconds == 2.0 * Scale.BASELINE_TARGET_SECONDS[index],
				"Every tier doubles the earlier march time without changing infantry speed.")
	_check(Scale.classify(0.0) == -1 and Scale.classify(NAN) == -1 and Scale.classify(INF) == -1,
			"Invalid values report no measured tier.")
	_check(Scale.planning_distance(-1) == -1.0 and Scale.planning_distance(5) == -1.0,
			"Invalid tier IDs do not invent a distance.")
	_check(Scale.classify(200.0) == Scale.Tier.COMPACT and Scale.classify(200.01) == Scale.Tier.SMALL,
			"Midpoint handling is deterministic.")
	_check(Scale.classify_baseline(96.67) == Scale.Tier.COMPACT
		and Scale.classify_baseline(109.02) == Scale.Tier.SMALL
		and Scale.classify_baseline(130.03) == Scale.Tier.STANDARD
		and Scale.classify_baseline(157.17) == Scale.Tier.LARGE
		and Scale.classify_baseline(174.2) == Scale.Tier.EXPANSIVE
		and Scale.within_baseline_band(174.2) and not Scale.within_target_band(174.2),
			"Existing routes retain their baseline categories but do not meet the doubled size band.")
	_check(Scale.classify(179.0) == Scale.Tier.COMPACT and not Scale.within_target_band(179.0)
		and Scale.classify(361.0) == Scale.Tier.EXPANSIVE and not Scale.within_target_band(361.0),
			"A nearest tier must not conceal an out-of-band march.")
	if _failures == 0:
		print("Battlefield scale: five targets, real formation speed, deterministic classification and out-of-band detection passed.")
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
