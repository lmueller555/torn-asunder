extends SceneTree

const Rescue := preload("res://game/battlefield/ilyra_spanwater_evacuation.gd")
const NEAR := Rescue.Group.NEAR
const FAR := Rescue.Group.FAR
const FIRST := Rescue.Launch.FIRST
const SECOND := Rescue.Launch.SECOND


func _initialize() -> void:
	var passed := _check_order_and_authored_steps() and _check_berth_and_pressure() \
		and _check_water_events_and_closure() and _check_empty_launch_recovery() and _check_losses_and_retry()
	if passed:
		print("Ilyra Spanwater: either household first, exclusive berth, recoverable contest/current/empty-boat loss, physical closure/exits, and defeat/retry passed.")
	quit(0 if passed else 1)


func _check_order_and_authored_steps() -> bool:
	for first_group in [NEAR, FAR]:
		var second_group := FAR if first_group == NEAR else NEAR
		var rescue := Rescue.new()
		var shortcut := _boarding(first_group, FIRST)
		shortcut.hero_called_group = first_group
		shortcut.first.crossed_boat_exit = true
		rescue.advance(shortcut)
		if rescue.group_status(first_group) != Rescue.GroupStatus.APPROACHING \
				or rescue.group_status(second_group) != Rescue.GroupStatus.SHELTERED:
			return _fail("Calling a group skipped its walk or also called the other group.")
		rescue.advance(shortcut)
		if rescue.group_status(first_group) != Rescue.GroupStatus.WAITING_AT_LANDING \
				or rescue.launch_status(FIRST) != Rescue.LaunchStatus.AVAILABLE:
			return _fail("Landing arrival granted boarding or an exit without a new observation.")
		rescue.advance(_boarding(first_group, FIRST))
		if rescue.group_status(first_group) != Rescue.GroupStatus.ABOARD or rescue.passenger_group(FIRST) != first_group:
			return _fail("A confirmed boarding did not put the first chosen group on the physically berthed launch.")
		var out_of_order := _exit(FIRST)
		rescue.advance(out_of_order)
		if rescue.launch_status(FIRST) != Rescue.LaunchStatus.LOADED:
			return _fail("A boat could exit without departing the berth.")
		_boat(out_of_order, FIRST).departed_low_landing = true
		rescue.advance(out_of_order)
		if rescue.launch_status(FIRST) != Rescue.LaunchStatus.UNDERWAY or rescue.group_status(first_group) != Rescue.GroupStatus.ABOARD:
			return _fail("A boat departed and crossed the exit in one update.")
		rescue.advance(_exit(FIRST))
		if rescue.group_status(first_group) != Rescue.GroupStatus.SAFE or rescue.outcome != Rescue.Outcome.ACTIVE:
			return _fail("One physical arrival either failed to save its passengers or incorrectly won.")
		_call_to_landing(rescue, second_group)
		_load_depart(rescue, second_group, SECOND)
		if rescue.advance(_exit(SECOND)) != Rescue.Outcome.SUCCEEDED or rescue.group_status(second_group) != Rescue.GroupStatus.SAFE:
			return _fail("Two actual exits did not clear the rescue in either boarding order.")
		var late := Rescue.Observation.new()
		late.hero_fell = true
		if rescue.advance(late) != Rescue.Outcome.SUCCEEDED or rescue.failure != Rescue.Failure.NONE:
			return _fail("A terminal clear was rewritten by a late defeat.")
	return true


func _check_berth_and_pressure() -> bool:
	var rescue := Rescue.new()
	_call_to_landing(rescue, FAR)
	var boarding := _boarding(FAR, SECOND)
	boarding.second.at_berth = false
	rescue.advance(boarding)
	boarding.second.at_berth = true
	boarding.first.at_berth = true
	rescue.advance(boarding)
	boarding.first.at_berth = false
	boarding.landing_contested = true
	rescue.advance(boarding)
	if rescue.group_status(FAR) != Rescue.GroupStatus.WAITING_AT_LANDING or rescue.passenger_group(SECOND) != Rescue.Group.NONE:
		return _fail("Boarding accepted no berth, dual occupancy, or contested landing.")
	boarding.landing_contested = false
	boarding.far.approach_contested = true
	for _step in range(100):
		rescue.advance(boarding)
	if rescue.group_status(FAR) != Rescue.GroupStatus.APPROACHING or rescue.outcome != Rescue.Outcome.ACTIVE:
		return _fail("A prolonged contested approach failed rather than waiting for recovery.")
	boarding.far.approach_contested = false
	rescue.advance(boarding)
	if rescue.group_status(FAR) != Rescue.GroupStatus.WAITING_AT_LANDING:
		return _fail("A group boarded on the same observation that confirmed its recovered approach.")
	rescue.advance(boarding)
	_call_to_landing(rescue, NEAR)
	rescue.advance(_boarding(NEAR, SECOND))
	if rescue.group_status(NEAR) != Rescue.GroupStatus.WAITING_AT_LANDING or rescue.passenger_group(SECOND) != FAR:
		return _fail("A second group overwrote the occupied launch's first manifest.")
	rescue.advance(_depart(SECOND))
	var held := _exit(SECOND)
	held.second.held_at_outflow_by_current = true
	for _step in range(100):
		rescue.advance(held)
	if rescue.launch_status(SECOND) != Rescue.LaunchStatus.HELD_AT_OUTFLOW \
			or rescue.group_status(FAR) != Rescue.GroupStatus.ABOARD or rescue.outcome != Rescue.Outcome.ACTIVE:
		return _fail("The current hold counted a blocked exit or became a hidden deadline.")
	rescue.advance(Rescue.Observation.new())
	if rescue.launch_status(SECOND) != Rescue.LaunchStatus.UNDERWAY or rescue.group_status(FAR) != Rescue.GroupStatus.ABOARD:
		return _fail("The ebb did not resume travel, or it substituted for a physical exit.")
	rescue.advance(_exit(SECOND))
	return rescue.group_status(FAR) == Rescue.GroupStatus.SAFE or _fail("A fresh physical exit did not finish the recovered launch.")


func _check_water_events_and_closure() -> bool:
	var rescue := Rescue.new()
	var rise := Rescue.Observation.new()
	rise.last_departure_warned = true
	rise.landing_closed_by_rise = true
	rescue.advance(rise)
	if rescue.release_started or rescue.last_departure_warned or rescue.landing_closed:
		return _fail("A stray closure event activated before the observed spillway release.")
	rise = Rescue.Observation.new()
	rise.spillway_release_started = true
	rise.last_departure_warned = true
	for _step in range(500):
		rescue.advance(rise)
	if not rescue.release_started or not rescue.last_departure_warned or rescue.landing_closed \
			or rescue.outcome != Rescue.Outcome.ACTIVE:
		return _fail("Last departure warning bypassed the actual waterline closure.")
	_call_to_landing(rescue, FAR)
	_load_depart(rescue, FAR, SECOND)
	_call_to_landing(rescue, NEAR)
	var late_board := _boarding(NEAR, FIRST)
	late_board.landing_closed_by_rise = true
	if rescue.advance(late_board) != Rescue.Outcome.FAILED or rescue.failure != Rescue.Failure.LANDING_CLOSED \
			or not rescue.landing_closed or rescue.failed_group != NEAR or rescue.passenger_group(FIRST) != Rescue.Group.NONE:
		return _fail("The rising landing admitted a same-tick late boarding or misidentified the stranded group.")

	rescue.restart()
	_call_to_landing(rescue, FAR)
	_load_depart(rescue, FAR, SECOND)
	_call_to_landing(rescue, NEAR)
	rescue.advance(_boarding(NEAR, FIRST))
	var closure := Rescue.Observation.new()
	closure.spillway_release_started = true
	closure.landing_closed_by_rise = true
	rescue.advance(closure)
	if not rescue.landing_closed or rescue.outcome != Rescue.Outcome.ACTIVE:
		return _fail("A proved closure falsely lost a group already aboard at the berth or away.")
	rescue.advance(_depart(FIRST))
	rescue.advance(_exit(SECOND))
	if rescue.outcome != Rescue.Outcome.ACTIVE or rescue.group_status(FAR) != Rescue.GroupStatus.SAFE:
		return _fail("A boat already away could not finish after the landing closed.")
	if rescue.advance(_exit(FIRST)) != Rescue.Outcome.SUCCEEDED:
		return _fail("Evacuees already loaded could not depart and finish after landing closure.")
	return true


func _check_empty_launch_recovery() -> bool:
	var rescue := Rescue.new()
	var disabled := Rescue.Observation.new()
	disabled.first.definitively_disabled = true
	rescue.advance(disabled)
	if rescue.outcome != Rescue.Outcome.ACTIVE or rescue.launch_status(FIRST) != Rescue.LaunchStatus.DISABLED:
		return _fail("An empty boat loss failed the rescue rather than losing only that boat.")
	_call_to_landing(rescue, NEAR)
	rescue.advance(_boarding(NEAR, FIRST))
	if rescue.group_status(NEAR) != Rescue.GroupStatus.WAITING_AT_LANDING:
		return _fail("A disabled boat was permitted to load.")
	_load_depart(rescue, NEAR, SECOND)
	rescue.advance(_exit(SECOND))
	_call_to_landing(rescue, FAR)
	var still_away := _exit(SECOND)
	still_away.far.at_low_landing = true
	rescue.advance(still_away)
	if rescue.launch_status(SECOND) != Rescue.LaunchStatus.CLEARED or rescue.group_status(FAR) != Rescue.GroupStatus.WAITING_AT_LANDING:
		return _fail("An exited boat started another trip without a physical return.")
	_load_depart(rescue, FAR, SECOND)
	if rescue.advance(_exit(SECOND)) != Rescue.Outcome.SUCCEEDED:
		return _fail("A surviving launch could not make another trip while the landing was physically open.")
	return true


func _check_losses_and_retry() -> bool:
	for reason in [Rescue.Failure.HERO_FELL, Rescue.Failure.HOUSEHOLDS_LOST, Rescue.Failure.OCCUPIED_LAUNCH_DISABLED]:
		var rescue := Rescue.new()
		_call_to_landing(rescue, NEAR)
		_load_depart(rescue, NEAR, FIRST)
		rescue.advance(_exit(FIRST))
		_call_to_landing(rescue, FAR)
		_load_depart(rescue, FAR, SECOND)
		var loss := _exit(SECOND)
		match reason:
			Rescue.Failure.HERO_FELL: loss.hero_fell = true
			Rescue.Failure.HOUSEHOLDS_LOST:
				loss.far.definitively_lost = true
				loss.near.definitively_lost = true
			Rescue.Failure.OCCUPIED_LAUNCH_DISABLED: loss.second.definitively_disabled = true
		if rescue.advance(loss) != Rescue.Outcome.FAILED or rescue.failure != reason \
				or rescue.group_status(NEAR) != Rescue.GroupStatus.SAFE or rescue.group_status(FAR) == Rescue.GroupStatus.SAFE:
			return _fail("A required loss did not take precedence over the simultaneous last exit.")
		if rescue.advance(_exit(SECOND)) != Rescue.Outcome.FAILED:
			return _fail("A subsequent exit reversed a terminal failure without retry.")
		rescue.restart()
		if rescue.outcome != Rescue.Outcome.ACTIVE or rescue.failure != Rescue.Failure.NONE \
				or rescue.failed_group != Rescue.Group.NONE or rescue.release_started or rescue.last_departure_warned \
				or rescue.landing_closed or rescue.group_status(NEAR) != Rescue.GroupStatus.SHELTERED \
				or rescue.group_status(FAR) != Rescue.GroupStatus.SHELTERED \
				or rescue.launch_status(SECOND) != Rescue.LaunchStatus.AVAILABLE or rescue.passenger_group(SECOND) != Rescue.Group.NONE:
			return _fail("Retry did not clear the releases, groups, manifests and defeat.")
	return true


func _call_to_landing(rescue: Rescue, group: Rescue.Group) -> void:
	var report := Rescue.Observation.new()
	report.hero_called_group = group
	rescue.advance(report)
	report.hero_called_group = Rescue.Group.NONE
	_households(report, group).at_low_landing = true
	rescue.advance(report)


func _load_depart(rescue: Rescue, group: Rescue.Group, launch: Rescue.Launch) -> void:
	rescue.advance(_boarding(group, launch))
	rescue.advance(_depart(launch))


func _boarding(group: Rescue.Group, launch: Rescue.Launch) -> Rescue.Observation:
	var report := Rescue.Observation.new()
	_households(report, group).at_low_landing = true
	_boat(report, launch).at_berth = true
	report.boarded_group = group
	report.boarding_launch = launch
	return report


func _depart(launch: Rescue.Launch) -> Rescue.Observation:
	var report := Rescue.Observation.new()
	_boat(report, launch).departed_low_landing = true
	return report


func _exit(launch: Rescue.Launch) -> Rescue.Observation:
	var report := Rescue.Observation.new()
	_boat(report, launch).crossed_boat_exit = true
	return report


func _households(report: Rescue.Observation, group: Rescue.Group) -> Rescue.GroupReport:
	return report.near if group == NEAR else report.far


func _boat(report: Rescue.Observation, launch: Rescue.Launch) -> Rescue.LaunchReport:
	return report.first if launch == FIRST else report.second


func _fail(message: String) -> bool:
	push_error(message)
	return false
