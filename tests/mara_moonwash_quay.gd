extends SceneTree

const Quay := preload("res://game/battlefield/mara_moonwash_quay.gd")
var _failures := 0


func _initialize() -> void:
	_check_withdrawal(Quay.Platoon.FIRST)
	_check_withdrawal(Quay.Platoon.SECOND)
	_check_ties_and_retry()
	_check_survivors_already_across()
	_check_hazard()
	if _failures == 0:
		print("Mara High Quay: both extraction orders, real survivors, terminal priority, order lock, safe lane warning and retry passed.")
	quit(0 if _failures == 0 else 1)


func _check_withdrawal(lead: Quay.Platoon) -> void:
	var model := Quay.new()
	var rear := Quay.Platoon.SECOND if lead == Quay.Platoon.FIRST else Quay.Platoon.FIRST
	var out: Array[int] = []
	model.platoon_extracted.connect(func(slot: Quay.Platoon) -> void: out.append(slot))
	var tick := Quay.Observation.new()
	tick.hero_crossed_upper_exit = true
	_set_platoon(tick, lead, _roster(["a", "b", "c"], ["a", "a", "unknown"]))
	_set_platoon(tick, rear, _roster(["rear"], []))
	_check(model.advance(tick) == Quay.Phase.WITHDRAWING and model.hero_extracted
		and model.can_order_platoon(lead) and model.can_order_platoon(rear) and out.is_empty(),
		"Hero or partial/duplicate crossings cannot clear or lock a formation early.")

	tick = Quay.Observation.new()
	# b fell between observations. a is already safe; only surviving c still
	# needs to cross, and the exit need not hold the entire group at once.
	_set_platoon(tick, lead, _roster(["a", "c"], ["c"]))
	_check(model.advance(tick) == Quay.Phase.WITHDRAWING and model.is_platoon_extracted(lead)
		and not model.can_order_platoon(lead) and model.can_order_platoon(rear) and out == [lead],
		"Whoever leads locks only when all current survivors have crossed.")

	tick = Quay.Observation.new()
	_set_platoon(tick, lead, _roster([], []))
	_set_platoon(tick, rear, _roster(["rear"], ["rear"]))
	_check(model.advance(tick) == Quay.Phase.SUCCEEDED and out == [lead, rear]
		and not model.can_order_platoon(lead) and not model.can_order_platoon(rear),
		"The rear guard plus previously safe hero and lead complete the withdrawal; no Ilyra rescue or levy flag is required.")


func _check_ties_and_retry() -> void:
	var model := Quay.new()
	var out: Array[int] = []
	model.platoon_extracted.connect(func(slot: Quay.Platoon) -> void: out.append(slot))
	var tick := Quay.Observation.new()
	tick.first = _roster(["a"], ["a"])
	tick.second = _roster(["b"], ["b"])
	_check(model.advance(tick) == Quay.Phase.WITHDRAWING and out.size() == 2,
		"Both platoons can escape before the hero, but the attempt does not clear.")
	tick = Quay.Observation.new()
	tick.hero_crossed_upper_exit = true
	tick.hero_defeated = true
	_check(model.advance(tick) == Quay.Phase.FAILED and model.failure == Quay.Failure.HERO_DEFEATED
		and not model.hero_extracted, "Hero defeat on the exit tick takes priority.")
	model.advance(Quay.Observation.new())
	_check(model.phase == Quay.Phase.FAILED and out.size() == 2, "A terminal attempt neither resets nor emits duplicate extraction.")

	model.restart()
	_check(model.phase == Quay.Phase.WITHDRAWING and model.failure == Quay.Failure.NONE
		and model.can_order_platoon(Quay.Platoon.FIRST) and model.can_order_platoon(Quay.Platoon.SECOND)
		and not model.can_order_platoon(-1) and not model.is_platoon_extracted(2),
		"Retry resets the hero, both extraction/order flags and rejects invalid slots.")

	tick = Quay.Observation.new()
	tick.hero_crossed_upper_exit = true
	tick.first = _roster(["a"], ["a"])
	tick.second = _roster([], ["dead"])
	_check(model.advance(tick) == Quay.Phase.FAILED and model.failure == Quay.Failure.SECOND_PLATOON_LOST
		and not model.is_platoon_extracted(Quay.Platoon.FIRST) and not model.hero_extracted,
		"A wiped platoon cannot be credited as extracted, even on a simultaneous friendly exit.")
	_check(out.size() == 2, "A failed tick does not emit incidental extraction from another group.")
	model.restart()
	tick = Quay.Observation.new()
	tick.first = _roster([], [])
	tick.second = _roster([], [])
	_check(model.advance(tick) == Quay.Phase.FAILED and model.failure == Quay.Failure.FIRST_PLATOON_LOST,
		"Simultaneous wipeouts return the stable first-platoon failure.")
	model.restart()
	tick = Quay.Observation.new()
	tick.first = _roster(["a"], [])
	model.advance(tick)
	_check(not model.is_platoon_extracted(Quay.Platoon.FIRST), "Retry clears individual crossing history.")


func _check_survivors_already_across() -> void:
	var model := Quay.new()
	var tick := Quay.Observation.new()
	tick.first = _roster(["safe", "rearguard"], ["safe"])
	model.advance(tick)
	tick = Quay.Observation.new()
	tick.first = _roster(["safe"], [])
	_check(model.advance(tick) == Quay.Phase.WITHDRAWING and model.is_platoon_extracted(Quay.Platoon.FIRST)
		and not model.can_order_platoon(Quay.Platoon.FIRST),
		"If the last soldier still inside is lost, the previous crossing of a living survivor still counts.")


func _check_hazard() -> void:
	var model := Quay.new()
	var cues: Array[String] = []
	model.lower_quay_warned.connect(func() -> void: cues.append("crack"))
	model.lower_quay_closed.connect(func() -> void: cues.append("closed"))
	var tick := Quay.Observation.new()
	tick.lower_quay_closure_requested = true
	tick.inland_route_open = true
	model.advance(tick)
	_check(model.lower_quay == Quay.LowerQuay.OPEN and cues.is_empty(), "A closure request cannot skip its crack warning.")
	tick.lower_quay_cracking = true
	model.advance(tick)
	_check(model.lower_quay == Quay.LowerQuay.WARNED and cues == ["crack"],
		"Even when both conditions arrive together, the warning is a separate tick.")
	tick.inland_route_open = false
	for i in range(5):
		model.advance(tick)
	_check(model.lower_quay == Quay.LowerQuay.WARNED and cues == ["crack"],
		"The site keeps its one warning and stays passable while the inland alternative is unsafe.")
	tick.inland_route_open = true
	model.advance(tick)
	model.advance(tick)
	_check(model.lower_quay == Quay.LowerQuay.CLOSED and cues == ["crack", "closed"],
		"With the inland route confirmed, lower-quay closure is emitted once.")
	model.restart()
	_check(model.lower_quay == Quay.LowerQuay.OPEN, "Retry clears the terrain cue state.")
	tick.hero_crossed_upper_exit = true
	tick.first = _roster(["a"], ["a"])
	tick.second = _roster(["b"], ["b"])
	_check(model.advance(tick) == Quay.Phase.SUCCEEDED and cues == ["crack", "closed"],
		"Delivery priority suppresses a fresh warning on a terminal tick.")


func _set_platoon(tick: Quay.Observation, slot: Quay.Platoon, record: Quay.PlatoonObservation) -> void:
	if slot == Quay.Platoon.FIRST:
		tick.first = record
	else:
		tick.second = record


func _roster(living: Array, crossed: Array) -> Quay.PlatoonObservation:
	var record := Quay.PlatoonObservation.new()
	record.living_members = PackedStringArray(living)
	record.crossed_upper_exit = PackedStringArray(crossed)
	return record


func _check(ok: bool, title: String) -> void:
	if not ok:
		_failures += 1
		push_error(title)
