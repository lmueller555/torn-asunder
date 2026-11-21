extends RefCounted
## Last Boat at Spanwater. Actors, interaction validation, water and movement
## belong to the battlefield. Nothing reads another campaign's progress.

const MISSION_ID := &"ilyra_spanwater_evacuation"

enum Group { NONE, NEAR, FAR }
enum Launch { NONE, FIRST, SECOND }
enum GroupStatus { UNKNOWN, SHELTERED, APPROACHING, WAITING_AT_LANDING, ABOARD, SAFE, LOST }
enum LaunchStatus { UNKNOWN, AVAILABLE, LOADED, UNDERWAY, HELD_AT_OUTFLOW, CLEARED, DISABLED }
enum Outcome { ACTIVE, SUCCEEDED, FAILED }
enum Failure { NONE, HERO_FELL, HOUSEHOLDS_LOST, OCCUPIED_LAUNCH_DISABLED, LANDING_CLOSED }

const GROUPS: Array[Group] = [Group.NEAR, Group.FAR]
const LAUNCHES: Array[Launch] = [Launch.FIRST, Launch.SECOND]


class GroupReport:
	var at_low_landing := false
	## Threat prevents approach/boarding but is not a confirmed casualty.
	var approach_contested := false
	var definitively_lost := false


class LaunchReport:
	var at_berth := false
	## Physical departure from the berth and crossing the exit are separate observations.
	var departed_low_landing := false
	var held_at_outflow_by_current := false
	var crossed_boat_exit := false
	var definitively_disabled := false


class Observation:
	var near := GroupReport.new()
	var far := GroupReport.new()
	var first := LaunchReport.new()
	var second := LaunchReport.new()
	## One confirmed new hero interaction, not merely an order aimed at a group.
	var hero_called_group := Group.NONE
	## Confirm a complete boarding at the physical berth, not a queued intent.
	var boarded_group := Group.NONE
	var boarding_launch := Launch.NONE
	var landing_contested := false
	## Visible battlefield events; no mission clock or Orc/Dryad save signal.
	var spillway_release_started := false
	var last_departure_warned := false
	var landing_closed_by_rise := false
	var hero_fell := false


var outcome: Outcome:
	get:
		return _outcome

var failure: Failure:
	get:
		return _failure

var failed_group: Group:
	get:
		return _failed_group

var release_started: bool:
	get:
		return _release_started

var last_departure_warned: bool:
	get:
		return _last_departure_warned

var landing_closed: bool:
	get:
		return _landing_closed


var _outcome := Outcome.ACTIVE
var _failure := Failure.NONE
var _failed_group := Group.NONE
var _release_started := false
var _last_departure_warned := false
var _landing_closed := false
var _groups: Array[GroupStatus] = [GroupStatus.SHELTERED, GroupStatus.SHELTERED]
var _launches: Array[LaunchStatus] = [LaunchStatus.AVAILABLE, LaunchStatus.AVAILABLE]
var _manifests: Array[Group] = [Group.NONE, Group.NONE]


func group_status(group: Group) -> GroupStatus:
	return _groups[group - 1] if group in GROUPS else GroupStatus.UNKNOWN


func launch_status(launch: Launch) -> LaunchStatus:
	return _launches[launch - 1] if launch in LAUNCHES else LaunchStatus.UNKNOWN


func passenger_group(launch: Launch) -> Group:
	return _manifests[launch - 1] if launch in LAUNCHES else Group.NONE


## Resolve confirmed losses and landing closure before this update's boarding
## and arrivals. A group still on the bank at closure can't board on that tick.
func advance(observation: Observation) -> Outcome:
	if _outcome != Outcome.ACTIVE:
		return _outcome
	if observation.hero_fell:
		return _fail(Failure.HERO_FELL)
	_release_started = _release_started or observation.spillway_release_started
	if _release_started:
		_last_departure_warned = _last_departure_warned or observation.last_departure_warned
		_landing_closed = _landing_closed or observation.landing_closed_by_rise

	for group in GROUPS:
		if group_status(group) != GroupStatus.SAFE and _group_report(observation, group).definitively_lost:
			return _lose_group(group, Failure.HOUSEHOLDS_LOST)
	for launch in LAUNCHES:
		if _launch_report(observation, launch).definitively_disabled:
			_launches[launch - 1] = LaunchStatus.DISABLED
			var occupied := passenger_group(launch)
			if occupied != Group.NONE:
				return _lose_group(occupied, Failure.OCCUPIED_LAUNCH_DISABLED)
	if _landing_closed:
		for group in GROUPS:
			if group_status(group) not in [GroupStatus.ABOARD, GroupStatus.SAFE]:
				return _fail(Failure.LANDING_CLOSED, group)

	# Only a launch already embarked at the start of this update can depart.
	for launch in LAUNCHES:
		_advance_launch(launch, _launch_report(observation, launch))
	if not _landing_closed:
		_advance_boarding(observation)
		for group in GROUPS:
			_advance_approach(group, _group_report(observation, group), observation.hero_called_group == group)
	if group_status(Group.NEAR) == GroupStatus.SAFE and group_status(Group.FAR) == GroupStatus.SAFE:
		_outcome = Outcome.SUCCEEDED
	return _outcome


func restart() -> void:
	_outcome = Outcome.ACTIVE
	_failure = Failure.NONE
	_failed_group = Group.NONE
	_release_started = false
	_last_departure_warned = false
	_landing_closed = false
	_groups = [GroupStatus.SHELTERED, GroupStatus.SHELTERED]
	_launches = [LaunchStatus.AVAILABLE, LaunchStatus.AVAILABLE]
	_manifests = [Group.NONE, Group.NONE]


func _advance_approach(group: Group, report: GroupReport, called: bool) -> void:
	match group_status(group):
		GroupStatus.SHELTERED:
			if called:
				_groups[group - 1] = GroupStatus.APPROACHING
		GroupStatus.APPROACHING, GroupStatus.WAITING_AT_LANDING:
			_groups[group - 1] = GroupStatus.WAITING_AT_LANDING 				if report.at_low_landing and not report.approach_contested else GroupStatus.APPROACHING


func _advance_boarding(observation: Observation) -> void:
	var group := observation.boarded_group
	var launch := observation.boarding_launch
	if group not in GROUPS or launch not in LAUNCHES or observation.landing_contested:
		return
	if group_status(group) != GroupStatus.WAITING_AT_LANDING or launch_status(launch) != LaunchStatus.AVAILABLE:
		return
	var households := _group_report(observation, group)
	var boat := _launch_report(observation, launch)
	var other_boat := _launch_report(observation, Launch.SECOND if launch == Launch.FIRST else Launch.FIRST)
	if households.approach_contested or not households.at_low_landing or not boat.at_berth 			or boat.departed_low_landing or boat.crossed_boat_exit or other_boat.at_berth:
		return
	_groups[group - 1] = GroupStatus.ABOARD
	_launches[launch - 1] = LaunchStatus.LOADED
	_manifests[launch - 1] = group


func _advance_launch(launch: Launch, report: LaunchReport) -> void:
	match launch_status(launch):
		LaunchStatus.LOADED:
			if report.departed_low_landing and not report.at_berth:
				_launches[launch - 1] = LaunchStatus.HELD_AT_OUTFLOW 					if report.held_at_outflow_by_current else LaunchStatus.UNDERWAY
		LaunchStatus.UNDERWAY, LaunchStatus.HELD_AT_OUTFLOW:
			if report.held_at_outflow_by_current:
				_launches[launch - 1] = LaunchStatus.HELD_AT_OUTFLOW
			elif report.crossed_boat_exit and not report.at_berth and not report.departed_low_landing:
				_groups[passenger_group(launch) - 1] = GroupStatus.SAFE
				_manifests[launch - 1] = Group.NONE
				_launches[launch - 1] = LaunchStatus.CLEARED
			else:
				_launches[launch - 1] = LaunchStatus.UNDERWAY
		LaunchStatus.CLEARED:
			# A surviving shuttle may take another group only after physically returning.
			if report.at_berth and not report.departed_low_landing and not report.crossed_boat_exit:
				_launches[launch - 1] = LaunchStatus.AVAILABLE


func _group_report(observation: Observation, group: Group) -> GroupReport:
	return observation.near if group == Group.NEAR else observation.far


func _launch_report(observation: Observation, launch: Launch) -> LaunchReport:
	return observation.first if launch == Launch.FIRST else observation.second


func _lose_group(group: Group, reason: Failure) -> Outcome:
	_groups[group - 1] = GroupStatus.LOST
	return _fail(reason, group)


func _fail(reason: Failure, group: Group = Group.NONE) -> Outcome:
	_outcome = Outcome.FAILED
	_failure = reason
	_failed_group = group
	return _outcome
