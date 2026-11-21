extends SceneTree

const Objective := preload("res://game/battlefield/sova_mine_tunnels.gd")
const Group := Objective.Group
const Status := Objective.GroupStatus
const Outcome := Objective.Outcome
const Failure := Objective.Failure


func _initialize() -> void:
	var evacuation_ok := _check_evacuation()
	var failures_ok := _check_failures()
	var passed := evacuation_ok and failures_ok
	if passed:
		print("Verified both work groups, recoverable outlet blockage, witness safety, defeat and restart.")
	quit(0 if passed else 1)


func _check_evacuation() -> bool:
	var objective := Objective.new()
	if objective.group_status(Group.MOUTH) != Status.STAGED or objective.group_status(Group.BEND) != Status.STAGING:
		return _fail("The groups did not start independently at the mouth and bend.")

	var frame := Objective.Observation.new()
	frame.bend.release_ordered = true
	frame.bend.at_druid_safety = true
	objective.advance(frame)
	if objective.group_status(Group.BEND) != Status.STAGING:
		return _fail("The group at the bend bypassed staging or release.")

	frame = Objective.Observation.new()
	frame.bend.in_staging_cover = true
	frame.mouth.release_ordered = true
	objective.advance(frame)
	if objective.group_status(Group.MOUTH) != Status.MOVING or objective.group_status(Group.BEND) != Status.STAGED:
		return _fail("The release did not move the selected group while the other staged.")

	frame = Objective.Observation.new()
	frame.outlet_blocked = true
	frame.bend.release_ordered = true
	frame.mouth.at_druid_safety = true
	if objective.advance(frame) != Outcome.ACTIVE:
		return _fail("A recoverable blockage ended the mission.")
	if objective.group_status(Group.MOUTH) != Status.PAUSED or objective.group_status(Group.BEND) != Status.STAGED:
		return _fail("A blocked outlet let a group depart or enter safety.")

	frame = Objective.Observation.new()
	frame.last_escape_window_closes = true
	if objective.advance(frame) != Outcome.ACTIVE or objective.group_status(Group.MOUTH) != Status.MOVING:
		return _fail("Clearing the outlet did not resume the released group.")
	if objective.group_status(Group.BEND) != Status.STAGED:
		return _fail("An order issued during blockage was unexpectedly queued.")

	frame = Objective.Observation.new()
	frame.mouth.at_druid_safety = true
	frame.bend.release_ordered = true
	frame.witness_waiting_under_truce = true
	if objective.advance(frame) != Outcome.ACTIVE or objective.group_status(Group.MOUTH) != Status.SAFE:
		return _fail("One group and the witness should not complete evacuation.")
	if objective.group_status(Group.BEND) != Status.MOVING:
		return _fail("A second release did not advance the group at the bend.")

	frame = Objective.Observation.new()
	frame.mouth.definitively_lost = true
	frame.bend.at_druid_safety = true
	if objective.advance(frame) != Outcome.ACTIVE or objective.group_status(Group.BEND) != Status.SAFE:
		return _fail("A stale loss report about the safe group invalidated the other group's arrival.")
	frame.witness_waiting_under_truce = true
	if objective.advance(frame) != Outcome.SUCCEEDED:
		return _fail("Two safe groups and the willing witness at the truce outlet should win without the Orc rally.")
	frame.sova_fell = true
	if objective.advance(frame) != Outcome.SUCCEEDED or objective.failure != Failure.NONE:
		return _fail("Late combat reports changed a completed evacuation.")
	objective.restart()
	if objective.outcome != Outcome.ACTIVE or objective.group_status(Group.BEND) != Status.STAGING:
		return _fail("Restart after victory retained evacuation progress.")
	return true


func _check_failures() -> bool:
	for expected in [Failure.SOVA_FELL, Failure.GROUP_LOST, Failure.WITNESS_LOST, Failure.OUTLET_WINDOW_CLOSED]:
		var objective := Objective.new()
		var frame := Objective.Observation.new()
		frame.mouth.release_ordered = true
		objective.advance(frame)
		frame = Objective.Observation.new()
		frame.mouth.at_druid_safety = true
		frame.bend.definitively_lost = expected == Failure.GROUP_LOST
		frame.sova_fell = expected == Failure.SOVA_FELL
		frame.witness_definitively_lost = expected == Failure.WITNESS_LOST
		frame.outlet_blocked = expected == Failure.OUTLET_WINDOW_CLOSED
		frame.last_escape_window_closes = frame.outlet_blocked
		if objective.advance(frame) != Outcome.FAILED or objective.failure != expected:
			return _fail("An irreversible loss did not give its expected result: %d." % expected)
		frame = Objective.Observation.new()
		frame.sova_fell = true
		if objective.advance(frame) != Outcome.FAILED or objective.failure != expected:
			return _fail("A terminal defeat or its reason changed.")
		objective.restart()
		if objective.outcome != Outcome.ACTIVE or objective.failure != Failure.NONE:
			return _fail("Restart after defeat retained the failure.")
		if objective.group_status(Group.MOUTH) != Status.STAGED or objective.group_status(Group.BEND) != Status.STAGING:
			return _fail("Restart after defeat did not restore the worker groups.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
