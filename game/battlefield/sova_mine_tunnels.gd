extends RefCounted
## Objective rules for The Workers' Way Out. The battlefield supplies events and safety zones.

const MISSION_ID := &"sova_mine_tunnels"

enum Group { MOUTH, BEND }
enum GroupStatus { STAGING, STAGED, MOVING, PAUSED, SAFE }
enum Outcome { ACTIVE, SUCCEEDED, FAILED }
enum Failure { NONE, SOVA_FELL, GROUP_LOST, WITNESS_LOST, OUTLET_WINDOW_CLOSED }


class GroupReport:
	var in_staging_cover := false
	## The selected group received a release order on this tick.
	var release_ordered := false
	## The group is at Druid safety. This is not the Orc rally point.
	var at_druid_safety := false
	var definitively_lost := false


class Observation:
	var mouth := GroupReport.new()
	var bend := GroupReport.new()
	var outlet_blocked := false
	## True on the tick the announced final escape window closes.
	var last_escape_window_closes := false
	var sova_fell := false
	var witness_waiting_under_truce := false
	var witness_definitively_lost := false


var outcome: Outcome:
	get:
		return _outcome

var failure: Failure:
	get:
		return _failure

var _outcome := Outcome.ACTIVE
var _failure := Failure.NONE
var _groups: Array[GroupStatus] = [GroupStatus.STAGED, GroupStatus.STAGING]


func group_status(group: Group) -> GroupStatus:
	return _groups[group]


## Submit one observation after combat, order and area checks. Irreversible losses
## take precedence over escape reports on the same tick.
func advance(observation: Observation) -> Outcome:
	if _outcome != Outcome.ACTIVE:
		return _outcome
	if observation.sova_fell:
		return _fail(Failure.SOVA_FELL)
	if (_lost_before_safety(Group.MOUTH, observation.mouth)
			or _lost_before_safety(Group.BEND, observation.bend)):
		return _fail(Failure.GROUP_LOST)
	if observation.witness_definitively_lost:
		return _fail(Failure.WITNESS_LOST)
	if observation.outlet_blocked and observation.last_escape_window_closes:
		return _fail(Failure.OUTLET_WINDOW_CLOSED)

	_advance_group(Group.MOUTH, observation.mouth, observation.outlet_blocked)
	_advance_group(Group.BEND, observation.bend, observation.outlet_blocked)
	if (_groups[Group.MOUTH] == GroupStatus.SAFE and _groups[Group.BEND] == GroupStatus.SAFE
			and observation.witness_waiting_under_truce):
		_outcome = Outcome.SUCCEEDED
	return _outcome


func restart() -> void:
	_groups[Group.MOUTH] = GroupStatus.STAGED
	_groups[Group.BEND] = GroupStatus.STAGING
	_outcome = Outcome.ACTIVE
	_failure = Failure.NONE


func _advance_group(group: Group, report: GroupReport, outlet_blocked: bool) -> void:
	match _groups[group]:
		GroupStatus.STAGING:
			if report.in_staging_cover:
				_groups[group] = GroupStatus.STAGED
		GroupStatus.STAGED:
			if report.release_ordered and not outlet_blocked:
				_groups[group] = GroupStatus.MOVING
		GroupStatus.MOVING, GroupStatus.PAUSED:
			if outlet_blocked:
				_groups[group] = GroupStatus.PAUSED
			elif report.at_druid_safety:
				_groups[group] = GroupStatus.SAFE
			else:
				_groups[group] = GroupStatus.MOVING


func _lost_before_safety(group: Group, report: GroupReport) -> bool:
	return _groups[group] != GroupStatus.SAFE and report.definitively_lost


func _fail(reason: Failure) -> Outcome:
	_failure = reason
	_outcome = Outcome.FAILED
	return _outcome
