extends RefCounted
## A Road We Can Share. Scene adapters own positions, screens and guide inputs.
## The vault escort and the Still Kingdom's stand have no inputs to this objective.

const MISSION_ID := &"neris_cairnspine_passage"

enum Outcome { ACTIVE, SUCCEEDED, FAILED }
enum Group { REFUGEES, WITNESSES }
enum Status { STAGED, WAITING, MOVING, BLOCKED, SAFE, LOST }
enum Route { NONE, SHELF, SIDE }
enum Failure { NONE, NERIS_FELL, REFUGEES_LOST, WITNESSES_LOST }


class GroupObservation:
	## A fresh interaction by Neris at a decision point. The adapter only
	## reports a route the group can take from its current safe marker.
	var route_confirmed := Route.NONE
	## Whether the next segment is clear for this group, including its
	## approach to the terrace. Threats behind it need not block its route.
	var shelf_open := false
	var side_open := false
	## The group itself reached safety, not merely the hero, guide or escort.
	var terrace_reached := false
	var lost := false


class Observation:
	var refugee_guide_met := false
	var witness_guide_signaled := false
	var neris_fell := false
	var refugees := GroupObservation.new()
	var witnesses := GroupObservation.new()


class GroupProgress:
	var status := Status.STAGED
	var route := Route.NONE


var outcome: Outcome:
	get:
		return _outcome

var failure: Failure:
	get:
		return _failure

var _outcome := Outcome.ACTIVE
var _failure := Failure.NONE
var _refugees := GroupProgress.new()
var _witnesses := GroupProgress.new()


func group_status(group: Group) -> Status:
	return _group(group).status


func group_route(group: Group) -> Route:
	return _group(group).route


## False means hold the party at its last safe marker. A blocked party resumes
## on the same route once it reopens, or Neris can freshly confirm the other one.
func may_advance(group: Group) -> bool:
	return _outcome == Outcome.ACTIVE and group_status(group) == Status.MOVING


## Report definitive losses before movement or arrivals. Confirmations to
## staged groups are ignored: guides and route decisions are separate actions.
func advance(observation: Observation) -> Outcome:
	if _outcome != Outcome.ACTIVE:
		return _outcome
	if observation.neris_fell:
		return _fail(Failure.NERIS_FELL)
	if observation.refugees.lost and _refugees.status != Status.SAFE:
		_refugees.status = Status.LOST
		return _fail(Failure.REFUGEES_LOST)
	if observation.witnesses.lost and _witnesses.status != Status.SAFE:
		_witnesses.status = Status.LOST
		return _fail(Failure.WITNESSES_LOST)

	var refugees_were_ready := _refugees.status != Status.STAGED
	_advance_group(_refugees, observation.refugees, observation.refugee_guide_met)
	_advance_group(_witnesses, observation.witnesses, refugees_were_ready and observation.witness_guide_signaled)
	if _refugees.status == Status.SAFE and _witnesses.status == Status.SAFE:
		_outcome = Outcome.SUCCEEDED
	return _outcome


func restart() -> void:
	_outcome = Outcome.ACTIVE
	_failure = Failure.NONE
	_refugees = GroupProgress.new()
	_witnesses = GroupProgress.new()


func _advance_group(group: GroupProgress, observation: GroupObservation, guide_ready: bool) -> void:
	if group.status == Status.SAFE:
		return
	if group.status == Status.STAGED:
		if guide_ready:
			group.status = Status.WAITING
		return
	var previous_route := group.route
	var was_moving := group.status == Status.MOVING
	if _route_open(observation.route_confirmed, observation):
		group.route = observation.route_confirmed
	if group.route == Route.NONE:
		return
	if not _route_open(group.route, observation):
		group.status = Status.BLOCKED
		return

	group.status = Status.MOVING
	# No stale arrival can complete a newly chosen or just resumed route.
	if was_moving and previous_route == group.route and observation.terrace_reached:
		group.status = Status.SAFE


func _route_open(route: Route, observation: GroupObservation) -> bool:
	return (route == Route.SHELF and observation.shelf_open) or (route == Route.SIDE and observation.side_open)


func _group(group: Group) -> GroupProgress:
	return _refugees if group == Group.REFUGEES else _witnesses


func _fail(reason: Failure) -> Outcome:
	_failure = reason
	_outcome = Outcome.FAILED
	return _outcome
